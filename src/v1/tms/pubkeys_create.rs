#![forbid(unsafe_code)]

use poem::Request;
use poem_openapi::{ OpenApi, payload::Json, Object, ApiResponse };
use anyhow::{anyhow, Result};
use chrono::{DateTime, Utc};

use crate::utils::authz::{authorize, AuthzTypes, get_client_id_header};
use crate::utils::errors::HttpResult;
use crate::utils::keygen::{self, KeyType};
use crate::utils::db_types::PubkeyInput;
use crate::utils::db::{insert_new_pubkey, check_rplogin_delegation, get_client_result, get_host_login_user_result};
use crate::utils::tms_utils::{self, timestamp_utc, calc_expires_at, RequestDebug, check_tms_id_enabled};
use crate::utils::implicit_mode::{ImplicitModeDependencyParms, create_pubkey_dependencies};
use log::{debug, error, trace, warn};
use regex::regex;
use crate::RUNTIME_CTX;
use crate::utils::config::TmsMode;

// NOTE: This const string appears in the code twice because the regex macro regex! requires a literal.
const HOST_LOGIN_REGEX: &str = "^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,63}$";

// ***************************************************************************
//                          Request/Response Definitions
// ***************************************************************************
pub struct NewSshKeysApi;

#[derive(Object)]
pub struct ReqNewSshKeys
{
    tms_identity: String,
    rp_id: String,
    rp_account: String,
    host: String,
    num_uses: i32,     // negative means i32::MAX
    ttl_minutes: i32,  // negative means i32::MAX
    key_type: Option<String>,  // RSA, ECDSA, ED25519, DEFAULT (=ED25519)
}

#[derive(Object, Debug)]
struct RespNewSshKeys
{
    result_code: String,
    result_msg: String,
    private_key: String,
    public_key: String,
    host_login_user: String,
    public_key_fingerprint: String,
    key_type: String,
    key_bits: String,
    max_uses: String,
    remaining_uses: String,
    expires_at: DateTime<Utc>,
}

// Implement the debug record trait for logging.
impl RequestDebug for ReqNewSshKeys {   
    type Req = ReqNewSshKeys;
    fn get_request_info(&self) -> String {
        let mut s = String::with_capacity(255);
        s.push_str("  Request body:");
        s.push_str("\n    tms_identity: ");
        s.push_str(&self.tms_identity);
        s.push_str("\n    rp_account: ");
        s.push_str(&self.rp_account);
        s.push_str("\n    host: ");
        s.push_str(&self.host);
        s.push_str("\n    num_uses: ");
        s.push_str(&self.num_uses.to_string());
        s.push_str("\n    ttl_minutes: ");
        s.push_str(&self.ttl_minutes.to_string());
        s.push_str("\n    key_type: ");
        let kt = match &self.key_type { Some(k) => k, None => "None" };
        s.push_str(kt);
        s.push('\n');
        s
    }
}

// ------------------- HTTP Status Codes -------------------
#[derive(Debug, ApiResponse)]
enum TmsResponse {
    #[oai(status = 201)]
    Http201(Json<RespNewSshKeys>),
    #[oai(status = 400)]
    Http400(Json<HttpResult>),
    #[oai(status = 401)]
    Http401(Json<HttpResult>),
    #[oai(status = 403)]
    Http403(Json<HttpResult>),
    #[oai(status = 500)]
    Http500(Json<HttpResult>)
}

fn make_http_201(resp: RespNewSshKeys) -> TmsResponse {
    TmsResponse::Http201(Json(resp))
}
fn make_http_400(msg: String) -> TmsResponse {
    TmsResponse::Http400(Json(HttpResult::new(400.to_string(), msg)))
}
fn make_http_401(msg: String) -> TmsResponse {
    TmsResponse::Http401(Json(HttpResult::new(401.to_string(), msg)))
}
fn make_http_403(msg: String) -> TmsResponse {
    TmsResponse::Http403(Json(HttpResult::new(403.to_string(), msg)))
}
fn make_http_500(msg: String) -> TmsResponse {
    TmsResponse::Http500(Json(HttpResult::new(500.to_string(), msg)))    
}

// ***************************************************************************
//                             OpenAPI Endpoint
// ***************************************************************************
#[OpenApi]
impl NewSshKeysApi {
    #[oai(path = "/tms/pubkeys/creds", method = "post")]
    async fn create_new_ssh_keys(&self, http_req: &Request, req: Json<ReqNewSshKeys>) -> TmsResponse {
        RespNewSshKeys::process(http_req, &req).await.unwrap_or_else(|e| {
            // Assume a server fault if a raw error came through.
            let msg = "WARNING: ".to_owned() + e.to_string().as_str();
            warn!("{}", msg);
            make_http_500(msg)
        })
    }
}

// ***************************************************************************
//                          Request/Response Methods
// ***************************************************************************
impl RespNewSshKeys {
    fn new(result_code: &str, result_msg: &str, private_key: String, public_key: String,
           host_login_user: String, public_key_fingerprint: String, key_type: String,
           key_bits: String, max_uses: String, remaining_uses: String, expires_at: DateTime<Utc>)
        -> Self {
        Self {result_code: result_code.to_string(), 
              result_msg: result_msg.to_string(), 
              private_key, public_key, public_key_fingerprint, host_login_user,
              key_type, key_bits, max_uses, remaining_uses, expires_at,
            }
    }

    // ========================================================================================
    //   Main endpoint processing method for createKeypair: POST /tms/pubkeys/creds
    // ========================================================================================
    async fn process(http_req: &Request, req: &ReqNewSshKeys) -> Result<TmsResponse> {
        // Log the request
        trace!("Createkey process");
        tms_utils::debug_request(http_req, req);

        // -------------------- Extract Headers ----------------------
        // Get the header we need: client_id
        let client_id = match get_client_id_header(http_req) {
            Ok(h) => h,
            Err(e) => { return Ok(make_http_400(e.to_string())); }
        };
        trace!("Createkey got client_id {}", client_id);

        // -------------------- Check Authorization ----------------------------
        // Only the client and admin can make this call
        let allowed = [AuthzTypes::ClientOwn, AuthzTypes::TmsAdmin];
        let authz_result = authorize(http_req, &allowed).await;
        if !authz_result.is_authorized() {
            let msg = format!("WARNING: Not authorized to create credential for client. ClientId: {}.",
                                     client_id);
            error!("{}", msg);
            return Ok(make_http_401(msg));
        }
        trace!("Createkey passed auth check");
        // Get the client record. We will need the tms_mode and enabled flag
        let client = match get_client_result(&client_id).await {
            Ok(c) => c,
            Err(e) => {
                let msg = format!("Unable to fetch client. ClientId: {} TmsUserId: {} Error: {}",
                                  client_id, req.tms_identity, e.to_string());
                return Ok(make_http_400(msg));
            }
        };
        trace!("Createkey got client");

        // Check that client is enabled
        if !client.enabled {
            let msg = format!("WARNING: Client not enabled. ClientId: {} TmsUserId: {}", client_id, req.tms_identity);
            error!("{}", msg);
            return Ok(make_http_400(msg));
        }
        trace!("Createkey client is enabled");

        // Check that tms_identity is enabled
        if !check_tms_id_enabled(&req.tms_identity).await {
            let msg = format!("WARNING: TMS Identity not enabled. ClientId: {} TmsUserId: {}", client_id, req.tms_identity);
            error!("{}", msg);
            return Ok(make_http_400(msg));
        }
        trace!("Createkey tms_id is enabled");

        // -------------------- MVP: IMPLICIT TRUST MODE ------------------------
        // If running in ImplicitTrust mode then automatically create delegation records.
        if RUNTIME_CTX.parms.config.enable_implicit && matches!(client.tms_mode, TmsMode::ImplicitTrust) {
            trace!("Createkey implicit");
            trace!("Createkey creating implicit_mode records");
            match setup_implicit_mode_records(&req, &*client_id).await {
                Ok(_) => {}
                Err(e) => {
                    let msg =
                        format!("ImplicitTrustMode Error setting up implicit trust records. ClientId: {} TmsUserId: {} Error: {}",
                                client_id, req.tms_identity, e.to_string());
                    error!("{}", msg);
                    return Ok(make_http_400(msg));
                }
            }
            trace!("Createkey created implicit records");
        }

        // --------------------- Check Login and delegation records -----------------------
        // The two tables that must be checked before we create this key are:
        //   resource_provider_logins - use (tms_identity,rp_id,rp_account) as unique key.
        //   delegations          - use (tms_identity, client_id, rp_id, rp_account) as unique key.
        //
        // If rp_login record does not exist it means the tms_identity needs to log in to the RP.
        // If delegation record does not exist or has expired it means the tms_identity needs
        //   to re-authorize (i.e. re-delegate) their RP account.
        //
        // This method returns either Ok or a message indicating why a new ssh keypair is not
        //   being created for the tms_identity.
        match check_rplogin_delegation(&req.tms_identity, &client_id, &req.rp_id, &req.rp_account).await
        {
            Ok(_) => (),
            Err(err) => {
                let err_msg = err.to_string();
                error!("{}", err_msg);
                if err_msg.contains("INTERNAL ERROR:") { return Ok(make_http_500(err_msg)); }
                let msg =
                    format!("Permission denied. Missing or expired login or delegation. ErrMsg: {}", err_msg);
                return Ok(make_http_403(msg));
            }
        }
        trace!("Createkey record check complete");

        // ------------------------ Generate Keys ------------------------
        // Get the provided key type or use default.
        let key_type_str = match &req.key_type {
            Some(k) => k.as_str(),
            None => "ED25519",
        };
        let key_type_upper = key_type_str.to_uppercase();

        // Get the enumerated key type.
        let key_type = match key_type_upper.as_str() {
            "RSA" => KeyType::Rsa,
            "ECDSA" => KeyType::Ecdsa,
            "ED25519" => KeyType::Ed25519,
            _ => KeyType::Ed25519,
        };

        // Generate the new key pair.
        let keyinfo = match keygen::generate_key(key_type) {
            Ok(k) => k,
            Err(e) => { return Err(anyhow!(e)); }
        };

        trace!("Createkey generated keypair");
        // Look up the host_login_user associated with the resource
        let host_login_user = match get_host_login_user_result(&req.rp_id, &req.rp_account).await {
            Ok(hlu) => hlu,
            Err(e) => {
                let msg =
                    format!("Unable to fetch host_login_user. ClientId: {} TmsUserId: {} RpId: {} RpAcct: {} Error: {}.",
                             client_id, req.tms_identity, req.rp_id, req.rp_account, e.to_string());
                error!("{}", msg);
                return Ok(make_http_400(msg));
            }
        };
        trace!("Createkey got host_login_user");

        // ------------------------ Update Database --------------------
        // Interpret numeric input.
        let max_uses = if req.num_uses < 0 {i32::MAX} else {req.num_uses};
        let ttl_minutes = if req.ttl_minutes < 0 {i32::MAX} else {req.ttl_minutes};

        // Use the same current UTC timestamp in all related time calculations.
        // We also use the original requested ttl_minutes to calculate expires_at so that we get a
        // uniform maximum uniform datetime rather than one that changes with current time when
        // req.ttl_minutes = -1.
        let now  = timestamp_utc();
        let expires_at  = calc_expires_at(now, req.ttl_minutes);
        let remaining_uses = max_uses;

        // Create the input record.
        let input_record = PubkeyInput::new(
            client_id.clone(),
            req.tms_identity.clone(),
            req.rp_id.clone(),
            req.rp_account.clone(),
            req.host.clone(),
            keyinfo.public_key_fingerprint.clone(),
            keyinfo.public_key.clone(),
            host_login_user.clone(),
            keyinfo.key_type.clone(),
            keyinfo.key_bits,
            max_uses,
            remaining_uses,
            ttl_minutes,
            expires_at.clone(),
            now.clone(),
            now.clone(),
        );

        // Insert the new key record.
        match insert_new_pubkey(input_record).await
        {
            Ok(_) => (),
            Err(err) => {
                let err_msg = err.to_string();
                error!("Unable to insert key-pair. Error: {}", err_msg);
                return Ok(make_http_500(err_msg));
            }
        }
        trace!("Createkey DONE, DB updated");

        // Success! Zero key bits means a fixed key length.
        Ok(make_http_201(Self::new("0", "success",
                keyinfo.private_key,
                keyinfo.public_key,
                host_login_user,
                keyinfo.public_key_fingerprint,
                keyinfo.key_type,
                keyinfo.key_bits.to_string(),
                max_uses.to_string(),
                remaining_uses.to_string(),
                expires_at)))
    }
}

// ***************************************************************************
//                          Private Functions
// ***************************************************************************

// /*
//  * Create login and delegation when a new key-pair is requested for an ImplicitTrust client.
//  */
async fn setup_implicit_mode_records(req: &ReqNewSshKeys, client_id: &str) -> Result<(), String>  {
    // Collect values required for dependency record insertions.
    // Extract subject from tms_identity that becomes our host_login_user, based on format someuser@some.domain
    let host_login_user: String;
    if let Some((host_login, _tms_id_domain)) = req.tms_identity.split_once('@') {
        host_login_user = host_login.to_string();
        debug!{"Found host login user: {}", host_login_user};
    } else {
        return Err("Unable to extract host_login_user from TMS identity.".to_string());
    }
    // Validate host login user
    match validate_host_login_user(&host_login_user).await {
        Ok(_) => {}
        Err(e) => {
            let msg =
                format!("Host login extracted from TMS identity is invalid. HostLoginUser: {} Error: {}",
                        host_login_user, e.to_string());
            return Err(msg);
        }
    }

    let implicit_trust_inputs = ImplicitModeDependencyParms {
        client_id: client_id.parse().unwrap(),
        tms_identity: req.tms_identity.clone(),
        rp_id: req.rp_id.clone(),
        rp_account: req.rp_account.clone(),
        host_login_user
    };
    // Insert records into the resource_provider_logins and delegations tables
    match create_pubkey_dependencies(implicit_trust_inputs).await {
        Ok(inserts) => {
            debug!("ImplicitTrustMode dependency records inserted. Count: {}", inserts);
            Ok(())
        },
        Err(e) => {
            let msg = format!("ImplicitTrustMode ERROR: Unable to create login and delegation records: {}", e);
            Err(msg)
        }
    }
}

/*
 * Method to check that a username appears to be a valid host login user
 *  - Check not empty
 *  - Check length. By RFC 5321, usernames for an email address or limited to 64 characters
 *  - Check against regex: r"^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,63}$"
 */
async fn validate_host_login_user(host_login: &str) -> Result<(), String> {
    if host_login.is_empty() { return Err("HostLogin cannot be empty".to_string()); }
    if host_login.len() > 64 { return Err("HostLogin too long, max 64 characters.".to_string()); }
    // Check regex
    // HOST_LOGIN_REGEX appears as hard-coded string because regex macro regex! requires a literal.
    if ! regex!("^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,63}$").is_match(host_login) {
        return Err(format!("HostLogin does not match regex: {}", HOST_LOGIN_REGEX));
    }
    Ok(())
}