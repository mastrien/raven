use std::env;

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub bind_addr: String,
    pub database_url: String,
    pub demo_codes_enabled: bool,
}

impl AppConfig {
    pub fn from_env() -> Self {
        let bind_addr = env::var("RAVEN_BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
        let database_url = env::var("RAVEN_DATABASE_URL").unwrap_or_else(|_| "sqlite://raven_backend.db".to_string());
        let demo_codes_enabled = env::var("RAVEN_DEMO_CODES")
            .map(|value| matches!(value.to_lowercase().as_str(), "1" | "true" | "yes" | "on"))
            .unwrap_or(true);

        Self {
            bind_addr,
            database_url,
            demo_codes_enabled,
        }
    }
}
