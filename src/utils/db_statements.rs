// This file contains all SQL statements issued by TMS.
#![forbid(unsafe_code)]

pub const PLACEHOLDER: &str = "${PLACEHOLDER}";

// ========================= identity_providers table =========================

pub const INSERT_IDP: &str = concat!(
"INSERT INTO identity_providers ",
  "(id, name, client_id, client_secret, identity_redirect_url, oauth2_token_url, provider_type,",
  " supports_login, supports_resources, created, updated) ",
  "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
);

pub const SEL_IDP_EXISTS: &str = "SELECT EXISTS(SELECT 1 FROM identity_providers WHERE id = $1)";

// ========================= tms_identities table ========================
// NOTE: We just need one in this table for referencing, so OK if it already exists.
pub const INSERT_TMS_IDENTITY: &str = concat!("INSERT INTO tms_identities (tms_identity, enabled) ",
     " VALUES ($1, $2) ON CONFLICT DO NOTHING");

pub const IS_TMS_ID_ENABLED: &str = "SELECT enabled FROM tms_identities where tms_identity = $1";


// ========================= clients table =========================
pub const INSERT_CLIENT: &str = concat!(
    "INSERT INTO clients (name, client_id, secret, enabled, created, updated) ",
    "VALUES ($1, $2, $3, $4, $5, $6)",
);

pub const IS_CLIENT_ENABLED: &str = "SELECT enabled FROM clients where client_id = $1";

pub const GET_CLIENT: &str = concat!(
    "SELECT id, name, client_id, secret, enabled, created, updated ",
    "FROM clients WHERE client_id = $1",
);

pub const SEL_CLIENT_EXISTS: &str = "SELECT EXISTS(SELECT 1 FROM clients WHERE client_id = $1)";

// Secret elided.
pub const LIST_CLIENTS_TEMPLATE: &str = concat!(
    "SELECT id, name, client_id, enabled, created, updated ",
    "FROM clients ${PLACEHOLDER} ORDER BY client_id",
);

// Conforms to the signature required for secret retrieval queries as defined by 
// get_authz_secret() in authz.rs.
pub const GET_CLIENT_SECRET: &str = "SELECT secret FROM clients WHERE client_id = $1";

pub const UPDATE_CLIENT_ENABLED: &str = "UPDATE clients SET enabled = $1, updated = $2 WHERE client_id = $3";

// ========================= resource_provider_logins table ========================
pub const INSERT_RP_LOGIN: &str = concat!(
    "INSERT INTO resource_provider_logins ",
    "(tms_identity, rp_id, rp_account, enabled, created, updated, last_login) ",
    "VALUES ($1, $2, $3, $4, $5, $6, $7)",
);

pub const INSERT_RP_LOGIN_NOT_STRICT: &str = concat!(
    "INSERT INTO resource_provider_logins (tms_identity, rp_id, rp_account, enabled, created, updated, last_login) ",
    "VALUES ($1, $2, $3, $4, $5, $7) ON CONFLICT DO NOTHING",
);

pub const GET_RP_LOGIN_ACTIVE: &str = concat!(
    "SELECT enabled ",
    "FROM resource_provider_logins WHERE tms_identity = $1 AND rp_id = $2 AND rp_account = $3"
);

pub const GET_RP_LOGIN_EXISTS: &str = concat!(
    "SELECT 1 FROM resource_provider_logins WHERE tms_identity = $1 AND rp_id = $2 AND rp_account = $3"
);

// ========================= user_delegations table =================
pub const INSERT_DELEGATION: &str = concat!(
    "INSERT INTO delegations (tms_identity, client_id, rp_id, rp_account, expires_at, created, updated) ",
    "VALUES ($1, $2, $3, $4, $5, $6, $7)",
);

pub const INSERT_DELEGATION_NOT_STRICT: &str = concat!(
    "INSERT INTO delegations (tms_identity, client_id, rp_id, rp_account, expires_at, created, updated) ",
    "VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING",
);

pub const GET_DELEGATION: &str = concat!(
    "SELECT id, tms_identity, client_id, rp_id, rp_account, expires_at, created, updated ",
    "FROM delegations WHERE tms_identity = $1 AND client_id = $2 AND rp_id = $3 AND rp_account = $4"
);

pub const GET_DELEGATION_ACTIVE: &str = concat!(
    "SELECT expires_at ",
    "FROM delegations WHERE tms_identity = $1 AND client_id = $2 AND rp_id = $3 AND rp_account = $4"
);

pub const SEL_DELEGATION_EXISTS: &str = concat!(
    "SELECT EXISTS(SELECT 1 FROM delegations ",
    "WHERE tms_identity = $1 AND client_id = $2 AND rp_id = $3 AND rp_account = $4)"
);

// ========================= pubkeys table =========================
pub const INSERT_PUBKEYS: &str = concat!(
    "INSERT INTO pubkeys (client_id, tms_identity, rp_id, rp_account, host, host_account, ",
      "public_key_fingerprint, public_key, key_type, key_bits, max_uses, remaining_uses, ",
      "initial_ttl_minutes, expires_at, created, updated) ",
    "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)",
);

pub const INSERT_PUBKEYS_NOT_STRICT: &str = concat!(
"INSERT INTO pubkeys (client_id, tms_identity, rp_id, rp_account, host, host_account, ",
"public_key_fingerprint, public_key, key_type, key_bits, max_uses, remaining_uses, ",
"initial_ttl_minutes, expires_at, created, updated) ",
"VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16) ",
"ON CONFLICT DO NOTHING"
);

pub const SELECT_PUBKEY: &str = concat!(
    "SELECT public_key, remaining_uses, expires_at FROM pubkeys ",
    "WHERE host_account = $1 AND host = $2 AND public_key_fingerprint = $3",
);

pub const SEL_PUBKEY_EXISTS: &str = "SELECT EXISTS(SELECT 1 FROM pubkeys WHERE host_account = $1 AND host = $2)";

pub const GET_PUBKEY: &str = concat!(
    "SELECT id, client_id, tms_identity, rp_id, rp_account, host, host_account, ",
      "public_key_fingerprint, public_key, key_type, key_bits, max_uses, remaining_uses, ",
      "initial_ttl_minutes, expires_at, created, updated ",
    "FROM pubkeys WHERE host_account = $1 AND host = $2 AND public_key_fingerprint = $3"
);

pub const DELETE_PUBKEY: &str = concat!(
    "DELETE FROM pubkeys WHERE client_id = $1 AND host = $2 AND public_key_fingerprint = $3"
);

// ========================= admins table ===========================
pub const SEL_ADMIN_EXISTS: &str = "SELECT EXISTS(SELECT 1 FROM admins WHERE admin_user = $1)";

pub const INSERT_ADMIN: &str = concat!(
    "INSERT INTO admins (admin_user, admin_secret, privilege, created, updated) ",
    "VALUES ($1, $2, $3, $4, $5)",
);

// Conforms to the signature required for secret retrieval queries as defined by 
// get_authz_secret() in authz.rs.
pub const GET_ADMIN_SECRET: &str = "SELECT admin_secret FROM admins WHERE admin_user = $1";

// // ========================= hosts table ===========================
// pub const INSERT_HOSTS: &str = "INSERT INTO hosts (host, addr, created, updated) VALUES ($1, $2, $3, $4)";
//
// pub const GET_HOST: &str = concat!(
//     "SELECT id, host, addr, created, updated ",
//     "FROM hosts WHERE id = $1"
// );
//
// pub const DELETE_HOST: &str = concat!(
//     "DELETE FROM hosts WHERE host = $1 AND addr = $2"
// );
//
// pub const LIST_HOSTS: &str = concat!(
//     "SELECT id, host, addr, created, updated ",
//     "FROM hosts ORDER BY host, addr",
// );
//
// ==================== reservations table =========================
// pub const INSERT_RESERVATIONS: &str = concat!(
//     "INSERT INTO reservations (resid, parent_resid, client_id, rp_id, rp_account, ",
//     "host, public_key_fingerprint, expires_at, created, updated) ",
//     "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
// );
//
//
// pub const GET_RESERVATION: &str = concat!(
//     "SELECT id, resid, parent_resid, client_id, rp_id, rp_account, host, ",
//     "public_key_fingerprint, expires_at, created, updated ",
//     "FROM reservations WHERE resid = $1",
// );
//
//
pub const GET_RESERVATION_FOR_EXTEND: &str = concat!(
    "SELECT parent_resid, expires_at FROM reservations ",
    "WHERE resid = $1 AND client_id = $2",
);
