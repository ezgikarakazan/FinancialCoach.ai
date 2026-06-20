from sqlalchemy import create_engine, text
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