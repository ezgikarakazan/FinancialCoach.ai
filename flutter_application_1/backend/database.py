from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker

DATABASE_URL = "sqlite:///./finance_ai.db"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)


def ensure_transaction_user_id_column() -> None:
    """Eski (auth öncesi) transactions tablosuna user_id kolonu ekler.

    SQLite ALTER TABLE ile NOT NULL + FK eklenemediği için kolon nullable
    olarak eklenir; sahibi belli olmayan (auth öncesi) satırlar silinir,
    çünkü hiçbir kullanıcıya atanamazlar.
    """
    inspector = inspect(engine)
    if "transactions" not in inspector.get_table_names():
        return

    columns = [col["name"] for col in inspector.get_columns("transactions")]
    if "user_id" in columns:
        return

    with engine.begin() as connection:
        connection.execute(text("ALTER TABLE transactions ADD COLUMN user_id INTEGER"))
        connection.execute(text("DELETE FROM transactions WHERE user_id IS NULL"))


def ensure_user_login_security_columns() -> None:
    """Eski users tablosuna brute-force koruması için gereken kolonları ekler."""
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    columns = [col["name"] for col in inspector.get_columns("users")]

    with engine.begin() as connection:
        if "failed_login_attempts" not in columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN failed_login_attempts INTEGER DEFAULT 0")
            )
        if "locked_until" not in columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN locked_until DATETIME"))


def test_connection() -> bool:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print("Database connection successful.")
        return True
    except SQLAlchemyError as exc:
        print(f"Database connection failed: {exc}")
        return False


if __name__ == "__main__":
    raise SystemExit(0 if test_connection() else 1)