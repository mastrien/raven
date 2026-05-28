use std::str::FromStr;

use sqlx::{sqlite::SqliteConnectOptions, SqlitePool};

use crate::error::ApiResult;

pub async fn connect(database_url: &str) -> ApiResult<SqlitePool> {
    let options = SqliteConnectOptions::from_str(database_url)?
        .create_if_missing(true)
        .foreign_keys(true);

    let pool = SqlitePool::connect_with(options).await?;
    Ok(pool)
}

pub async fn migrate(pool: &SqlitePool) -> ApiResult<()> {
    let migration = include_str!("../migrations/001_init.sql");

    for statement in migration.split(';') {
        let statement = statement.trim();
        if !statement.is_empty() {
            if let Err(error) = sqlx::query(statement).execute(pool).await {
                let message = error.to_string();
                if !message.contains("duplicate column name") {
                    return Err(error.into());
                }
            }
        }
    }

    Ok(())
}
