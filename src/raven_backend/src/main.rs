mod config;
mod db;
mod error;
mod models;
mod routes;
mod services;

use std::{net::SocketAddr, sync::Arc};

use axum::{routing::get, Json, Router};
use config::AppConfig;
use models::HealthResponse;
use sqlx::SqlitePool;
use tokio::net::TcpListener;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub config: AppConfig,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "raven_backend=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = AppConfig::from_env();
    let db = db::connect(&config.database_url).await?;
    db::migrate(&db).await?;

    let state = Arc::new(AppState {
        db,
        config: config.clone(),
    });

    let app = Router::new()
        .route("/health", get(health))
        .nest("/auth", routes::auth::router())
        .nest("/users", routes::users::router())
        .merge(routes::messages::router())
        .merge(routes::groups::router())
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr: SocketAddr = config.bind_addr.parse()?;
    let listener = TcpListener::bind(addr).await?;

    tracing::info!("Raven backend listening on http://{}", addr);
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        ok: true,
        service: "raven_backend".to_string(),
    })
}
