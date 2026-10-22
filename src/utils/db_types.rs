// This file contains the TMS database structs and related definitions.
#![forbid(unsafe_code)]

use chrono::{DateTime, Utc};
use serde::Deserialize;
use crate::utils::config::TmsMode;

// ---------------------------------------------------------------------------
// pubkeys:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct Pubkey {
    pub id: i32,
    pub client_id: String,
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub host: String,
    pub public_key_fingerprint: String,
    pub public_key: String,
    pub host_login_user: String,
    pub key_type: String,
    pub key_bits: i32,
    pub max_uses: i32,
    pub remaining_uses: i32,
    pub initial_ttl_minutes: i32,
    pub expires_at: DateTime<Utc>,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct PubkeyInput {
    pub client_id: String,
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub host: String,
    pub public_key_fingerprint: String,
    pub public_key: String,
    pub host_login_user: String,
    pub key_type: String,
    pub key_bits: i32,
    pub max_uses: i32,
    pub remaining_uses: i32,
    pub initial_ttl_minutes: i32,
    pub expires_at: DateTime<Utc>,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

impl Pubkey {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: i32,
        client_id: String,
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        host: String,
        public_key_fingerprint: String,
        public_key: String,
        host_login_user: String,
        key_type: String,
        key_bits: i32,
        max_uses: i32,
        remaining_uses: i32,
        initial_ttl_minutes: i32,
        expires_at: DateTime<Utc>,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    ) 
    -> Pubkey {
        Pubkey {
            id, client_id, tms_identity, rp_id, rp_account, host, public_key_fingerprint,
            public_key, host_login_user, key_type, key_bits, max_uses, remaining_uses, initial_ttl_minutes,
            expires_at, created, updated
        }
    }
}

impl PubkeyInput {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        client_id: String,
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        host: String,
        public_key_fingerprint: String,
        public_key: String,
        host_login_user: String,
        key_type: String,
        key_bits: i32,
        max_uses: i32,
        remaining_uses: i32,
        initial_ttl_minutes: i32,
        expires_at: DateTime<Utc>,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    ) 
    -> PubkeyInput {
        PubkeyInput {
            client_id, tms_identity, rp_id, rp_account, host, public_key_fingerprint,
            public_key, host_login_user, key_type, key_bits, max_uses, remaining_uses,
            initial_ttl_minutes, expires_at, created, updated
        }
    }
}

// ---------------------------------------------------------------------------
// identity_providers:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
pub struct IdPInput {
    pub id: String,
    pub name: String,
    pub client_id: String,
    pub client_secret: String,
    pub identity_redirect_url: String,
    pub oauth2_token_url: String,
    pub provider_type: String,
    pub supports_login: bool,
    pub supports_resources: bool,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>
}
impl IdPInput {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: String,
        name: String,
        client_id: String,
        client_secret: String,
        identity_redirect_url: String,
        oauth2_token_url: String,
        provider_type: String,
        supports_login: bool,
        supports_resources: bool,
        created: DateTime<Utc>,
        updated: DateTime<Utc>
    )
        -> IdPInput {
        IdPInput { id, name, client_id, client_secret, identity_redirect_url, oauth2_token_url,
                   provider_type, supports_login, supports_resources, created, updated }
        }
    }

// ---------------------------------------------------------------------------
// clients:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct Client {
    pub id: i32,
    pub name: String,
    pub client_id: String,
    pub secret: String,
    pub rp_id: String,
    pub tms_mode: TmsMode,
    pub enabled: bool,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct ClientInput {
    pub name: String,
    pub client_id: String,
    pub secret: String,
    pub rp_id: String,
    pub tms_mode: TmsMode,
    pub enabled: bool,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

impl Client {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: i32,
        name: String,
        client_id: String,
        secret: String,
        rp_id: String,
        tms_mode: TmsMode,
        enabled: bool,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    ) 
    -> Client {
        Client {
            id, name, client_id, secret, rp_id, tms_mode, enabled, created, updated }
    }
}

impl ClientInput {
        #[allow(dead_code, clippy::too_many_arguments)]
        pub fn new(
            name: String,
            client_id: String,
            secret: String,
            rp_id: String,
            tms_mode: TmsMode,
            enabled: bool,
            created: DateTime<Utc>,
            updated: DateTime<Utc>,
        ) 
        -> ClientInput {
            ClientInput { name, client_id, secret, rp_id, tms_mode, enabled, created, updated }
        }
}

// ---------------------------------------------------------------------------
// rp_login:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct RPLogin {
    pub id: i32,
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub enabled: bool,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
    pub last_login: DateTime<Utc>
}

#[derive(Debug, Deserialize)]
pub struct RPLoginInput {
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub enabled: bool,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
    pub last_login: DateTime<Utc>
}

impl RPLogin {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: i32,
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        enabled: bool,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
        last_login: DateTime<Utc>
    )
        -> RPLogin {
        RPLogin { id, tms_identity, rp_id, rp_account, enabled, created, updated, last_login }
    }
}

impl RPLoginInput {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        enabled: bool,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
        last_login: DateTime<Utc>
    )
    -> RPLoginInput {
        RPLoginInput { tms_identity, rp_id, rp_account, enabled, created, updated, last_login }
    }
}

// ---------------------------------------------------------------------------
// delegation:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct Delegation {
    pub id: i32,
    pub client_id: String,
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub expires_at: DateTime<Utc>,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct DelegationInput {
    pub client_id: String,
    pub tms_identity: String,
    pub rp_id: String,
    pub rp_account: String,
    pub expires_at: DateTime<Utc>,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

impl Delegation {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: i32,
        client_id: String,
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        expires_at: DateTime<Utc>,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    )
    -> Delegation {
        Delegation { id, client_id, tms_identity, rp_id, rp_account, expires_at, created, updated }
    }
}

impl DelegationInput {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        client_id: String,
        tms_identity: String,
        rp_id: String,
        rp_account: String,
        expires_at: DateTime<Utc>,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    )
    -> DelegationInput {
        DelegationInput { client_id, tms_identity, rp_id, rp_account, expires_at, created, updated }
    }
}

// ---------------------------------------------------------------------------
// hosts:
// ---------------------------------------------------------------------------
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct Host {
    pub id: i32,
    pub host: String,
    pub addr: String,
    pub created: DateTime<Utc>,
    pub updated: DateTime<Utc>,
}

impl Host {
    #[allow(dead_code, clippy::too_many_arguments)]
    pub fn new(
        id: i32,
        host: String,
        addr: String,
        created: DateTime<Utc>,
        updated: DateTime<Utc>,
    ) 
    -> Host {
        Host { id, host, addr, created, updated }
    }
}
