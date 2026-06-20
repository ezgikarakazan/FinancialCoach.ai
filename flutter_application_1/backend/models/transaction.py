from sqlalchemy import Column, Integer, String, Numeric, Date
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)  # Para için Decimal
    category = Column(String(100), nullable=False)
    date = Column(Date, nullable=False)