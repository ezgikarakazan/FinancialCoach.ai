from sqlalchemy import Column, Integer, String, Numeric, Date, DateTime, ForeignKey, func
from sqlalchemy.orm import relationship

from models.transaction import Base


class PdfUpload(Base):
    __tablename__ = "pdf_uploads"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    filename = Column(String(255), nullable=False)
    file_hash = Column(String(64), nullable=False, index=True)
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    items = relationship(
        "PdfUploadItem",
        backref="upload",
        cascade="all, delete-orphan",
        order_by="PdfUploadItem.id",
    )


class PdfUploadItem(Base):
    __tablename__ = "pdf_upload_items"

    id = Column(Integer, primary_key=True, index=True)
    upload_id = Column(Integer, ForeignKey("pdf_uploads.id"), nullable=False, index=True)
    date = Column(Date, nullable=False)
    title = Column(String(255), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(100), nullable=False)
    status = Column(String(20), nullable=False, default="pending")  # pending | added | skipped
    transaction_id = Column(Integer, ForeignKey("transactions.id"), nullable=True)
