#![forbid(unsafe_code)]

use poem::Request;
use poem_openapi::{ OpenApi, payload::Json, Object, ApiResponse };
use anyhow::{anyhow, Result};
use sqlx::Row;

use crate::utils::errors::HttpResult;
use crate::utils::db_statements::{GET_PUBKEY, SELECT_PUBKEY};
use crate::utils::db_types::Pubkey;
use crate::utils::db_types::PubkeyRetrieval;
use crate::utils::{tms_utils, tms_utils::RequestDebug};
use log::error;
use crate::RUNTIME_CTX;
use crate::utils::db::check_rplogin_delegation;
use crate::utils::tms_utils::check_client_enabled;

// ***************************************************************************
//                          Request/Response Definitions
// ***************************************************************************
pub struct PublicKeyApi;

#[derive(Object)]
struct ReqPublicKey
{
    user: String,
    user_uid: Option<String>,
    host: String,
    public_key_fingerprint: String // protocol:base64hash format
}

#[derive(Object, Debug)]
struct RespPublicKey
{
    result_code: String,
    result_msg: String,
    public_key: String,
}

// Implement the debug record trait for logging.
impl RequestDebug for ReqPublicKey {   
    type Req = ReqPublicKey;
    fn get_request_info(&self) -> String {
        let mut s = String::with_capacity(255);
        s.push_str("  Request body:");
        s.push_str("\n    user: ");
        s.push_str(&self.user);
        s.push_str("\n    user_uid: ");
        let uid = match &self.user_uid {
            Some(k) => k,
            None => "None",
        };
        s.push_str(uid);
        s.push_str("\n    host: ");
        s.push_str(&self.host);
        s.push_str("\n    public_key_fingerprint: ");
        s.push_str(&self.public_key_fingerprint);
        s.push('\n');
        s
    }
}

// ------------------- HTTP Status Codes -------------------
#[derive(Debug, ApiResponse)]
enum TmsResponse {
    #[oai(status = 200)]
    Http200(Json<RespPublicKey>),
    #[oai(status = 403)]
    Http403(Json<HttpResult>),
    #[oai(status = 404)]
    Http404(Json<HttpResult>),
    #[oai(status = 500)]
    Http500(Json<HttpResult>),
}

fn make_http_200(resp: RespPublicKey) -> TmsResponse {
    TmsResponse::Http200(Json(resp))
}
fn make_http_400(msg: String) -> TmsResponse {
    TmsResponse::Http403(Json(HttpResult::new(403.to_string(), msg)))
}
fn make_http_403(msg: String) -> TmsResponse {
    TmsResponse::Http403(Json(HttpResult::new(403.to_string(), msg)))
}
fn make_http_404(msg: String) -> TmsResponse {
    TmsResponse::Http404(Json(HttpResult::new(404.to_string(), msg)))
}
fn make_http_500(msg: String) -> TmsResponse {
    TmsResponse::Http500(Json(HttpResult::new(500.to_string(), msg)))    
}

// ***************************************************************************
//                             OpenAPI Endpoint
// ***************************************************************************
#[OpenApi]
impl PublicKeyApi {
    #[oai(path = "/tms/pubkeys/creds/retrieve", method = "post")]
    async fn get_public_key(&self, http_req: &Request, req: Json<ReqPublicKey>) -> TmsResponse {
        RespPublicKey::process(http_req, &req).await.unwrap_or_else(|e| {
            let msg = "ERROR: ".to_owned() + e.to_string().as_str();
            error!("{}", msg);
            make_http_500(msg)
        })
    }
}

// ***************************************************************************
//                          Request/Response Methods
// ***************************************************************************
impl RespPublicKey {
    fn new(result_code: &str, result_msg: &str, key: &str) -> Self {
        Self {result_code: result_code.to_string(), 
              result_msg: result_msg.to_string(), 
              public_key: key.to_string()}
    }

    async fn process(http_req: &Request, req: &ReqPublicKey) -> Result<TmsResponse> {
        // Log the request
        tms_utils::debug_request(http_req, req);

        let db_result = get_public_key(req).await;
        match db_result {
            Ok(result) => {
                Ok(make_http_200(Self::new("0", "success", result.public_key.as_str())))
            },
            Err(e) => {
                // Determine if this is a real db error or just record not found.
                let msg = e.to_string();
                if msg.contains("NOT_FOUND") {Ok(make_http_404(msg))} 
                  else {Err(e)}
            },
        }

        // TODO NOTE: Should we check? Yes, we should check. What if the client is temporarily disabled?
        //  And what if the mfa or delegation has expired per policy?
        //  If we count on the pubkey always being removed in such cases then the
        //  application (or maybe tms_server) would need to re-create the key.
        //  TMS server would not be able to automatically re-generate a keypair,
        //  because without an existing pubkey record we cannot lookup client_id, rp_id, rp_account.
        //
        // TODO -------------------- Extract Headers ----------------------
        // NOTE: Get the header we need: ???
        //      Currently, KeyCmd does not set in headers. For DangerMode operation we will need
        //      some secure way of specifying it, so we maybe use a header?
        // BUT, on a given host we will have some clients using DangerMode and some not, so
        //   on the host side it cannot be a boolean.
        //   Maybe for now the best we can do for security is to have a special client id + secret
        //   so a host can prove itself to the TMS credential server.
        //   Would need to work out how to register these special clients.

        // Check that valid rp_login and delegation records are in place. If not return 403.
        // At this point we do not have tms_identity, client_id, rp_id, rp_account.
        // All we have are values from host: user, user_uid, host, public_key_fingerprint
        // But, since the fingerprint is unique, if we do find it in the pubkeys table we can
        //    look up what we need for the rp_login and delegation checks from the pubkeys table.
        //    What we need: tms_identity, client_id, rp_id, rp_account
        // Get the full pubkey record. If it does not exist we are done.
        // If we have it, then we use attributes from that record to check for valid rp_login and
        // delegation records. If not return 403

        // // Look for the key in the database. If found save the result,
        // //    else if not found return 404 else internal error return 500
        // let full_pubkey_result = get_full_pubkey_result(req).await;
        // let full_pubkey = match full_pubkey_result {
        //     Ok(pubkey) => pubkey,
        //     Err(err) => {
        //         // Determine if this is a real error or just record not found.
        //         let msg = err.to_string();
        //         if msg.contains("NOT_FOUND") { return Ok(make_http_404(msg)) }
        //         else { return Err(err) }
        //     }
        // };
        // // We now have what we need to check if client is enabled and check the rp_login and
        // // delegation records.
        // Check client.
        // if !check_client_enabled(&full_pubkey.req.client_id).await {
        //     let msg = format!("WARNING: Client not enabled. ClientId: {}", full_pubkey.client_id);
        //     error!("{}", msg);
        //     return Ok(make_http_400(msg));
        // }
        // match check_rplogin_delegation(&full_pubkey.tms_identity, &full_pubkey.client_id,
        //                                &full_pubkey.rp_id, &full_pubkey.rp_account).await
        // {
        //     Ok(_) => (),
        //     Err(err) => {
        //         let err_msg = err.to_string();
        //         error!("{}", err_msg);
        //         if err_msg.contains("INTERNAL ERROR:") { return Ok(make_http_500(err_msg)); }
        //         let msg =
        //             format!("Permission denied. Missing or expired login or delegation. User: {} Host: {} PubKey: {} ErrMsg: {}",
        //                     req.user, req.host, req.public_key_fingerprint, err_msg);
        //         return Ok(make_http_403(msg));
        //     }
        // };
        // // We have valid rp_login and delegation records, we can return the public key.
        // Ok(make_http_200(Self::new("0", "success", full_pubkey.public_key.as_str())))
    }
}

// ***************************************************************************
//                          Private Functions
// ***************************************************************************
// ---------------------------------------------------------------------------
// get_public_key:
// ---------------------------------------------------------------------------
async fn get_public_key(req: &ReqPublicKey) -> Result<PubkeyRetrieval> {
    // Get a connection to the db and start a transaction.  Uncommited transactions 
    // are automatically rolled back when they go out of scope. 
    // See https://docs.rs/sqlx/latest/sqlx/struct.Transaction.html.
    let mut tx = RUNTIME_CTX.db.begin().await?;
    
    // Create the insert statement.
    let result = sqlx::query(SELECT_PUBKEY)
        .bind(&req.user)
        .bind(&req.host)
        .bind(&req.public_key_fingerprint)
        .fetch_optional(&mut *tx)
        .await?;

    // Commit the transaction.
    tx.commit().await?;

    // We found the key!
    match result {
        Some(row) => {
            Ok(PubkeyRetrieval::new(row.get(0), row.get(1), row.get(2)))
        },
        None => {
            Err(anyhow!("NOT_FOUND"))
        },
    }
}

// get_full_pubkey_result:
// Fetch the full public key record using the fingerprint, host and host_user
// ---------------------------------------------------------------------------
async fn get_full_pubkey_result(req: &ReqPublicKey) -> Result<Pubkey> {
    // Get a connection to the db and start a transaction.
    let mut tx = RUNTIME_CTX.db.begin().await?;
    // Create the select statement.
    let result = sqlx::query(GET_PUBKEY)
        .bind(&req.user)
        .bind(&req.host)
        .bind(&req.public_key_fingerprint)
        .fetch_optional(&mut *tx)
        .await?;
    // Commit the transaction.
    tx.commit().await?;

    // Return the result or an error.
    match result {
        Some(row) => {
            Ok(Pubkey::new(row.get(0), row.get(1), row.get(2), row.get(3),
                           row.get(4), row.get(5), row.get(6), row.get(7),
                           row.get(8), row.get(9), row.get(10), row.get(11),
                           row.get(12), row.get(13), row.get(14), row.get(15),
                           row.get(16)))
        },
        None => {Err(anyhow!("NOT_FOUND"))},
    }
}
