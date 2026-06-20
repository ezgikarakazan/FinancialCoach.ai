from datetime import date
from decimal import Decimal
from typing import List

import os
import shutil

import fitz  # PyMuPDF
import pdfplumber
import pytesseract
from PIL import Image
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from database import SessionLocal, engine
from models.transaction import Base, Transaction
from collections import defaultdict


app = FastAPI(
    title="AI Finance Coach API",
    version="1.0.0",
)

Base.metadata.create_all(bind=engine)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class TransactionCreate(BaseModel):
    title: str
    amount: Decimal
    category: str
    date: date


class TransactionOut(BaseModel):
    id: int
    title: str
    amount: Decimal
    category: str
    date: date

    model_config = ConfigDict(from_attributes=True)

MONTH_NAMES_TR = {
    1: "Oca",
    2: "Sub",
    3: "Mar",
    4: "Nis",
    5: "May",
    6: "Haz",
    7: "Tem",
    8: "Agu",
    9: "Eyl",
    10: "Eki",
    11: "Kas",
    12: "Ara",
}


def format_month_label(month_key: str) -> str:
    year_str, month_str = month_key.split("-")
    month_num = int(month_str)
    return f"{MONTH_NAMES_TR.get(month_num, month_str)} {year_str}"
def extract_pdf_text(file_path: str) -> str:
    text_chunks: List[str] = []

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            text_chunks.append(page.extract_text() or "")

    return "\n".join(text_chunks).strip()


def extract_pdf_text_with_ocr(file_path: str) -> str:
    tesseract_cmd = os.getenv("TESSERACT_CMD", r"C:\Program Files\Tesseract-OCR\tesseract.exe")
    if os.path.exists(tesseract_cmd):
        pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    ocr_chunks: List[str] = []

    with fitz.open(file_path) as doc:
        for page in doc:
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            mode = "RGBA" if pix.alpha else "RGB"
            img = Image.frombytes(mode, [pix.width, pix.height], pix.samples)

            try:
                page_text = pytesseract.image_to_string(img, lang="tur+eng")
            except Exception:
                page_text = pytesseract.image_to_string(img, lang="eng")

            ocr_chunks.append(page_text or "")

    return "\n".join(ocr_chunks).strip()


@app.get("/")
def home():
    return {"message": "AI Finance Coach API"}


@app.get("/dashboard")
def dashboard(db: Session = Depends(get_db)):
    items = (
        db.query(Transaction)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .all()
    )

    income = 0.0
    expense = 0.0
    recent_transactions = []

    for item in items:
        amount_value = float(item.amount or 0)

        if amount_value > 0:
            income += amount_value
        elif amount_value < 0:
            expense += abs(amount_value)

        recent_transactions.append(
            {
                "id": item.id,
                "title": item.title,
                "amount": amount_value,
                "category": item.category,
                "date": item.date.isoformat() if item.date else None,
            }
        )

    saving = income - expense

    if income <= 0:
        risk = "High"
    else:
        expense_ratio = expense / income
        if expense_ratio < 0.5:
            risk = "Low"
        elif expense_ratio < 0.8:
            risk = "Medium"
        else:
            risk = "High"

    return {
        "income": round(income, 2),
        "expense": round(expense, 2),
        "saving": round(saving, 2),
        "risk": risk,
        "recent_transactions": recent_transactions[:3],
    }


@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    os.makedirs("uploads", exist_ok=True)
    file_path = os.path.join("uploads", file.filename)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        text = extract_pdf_text(file_path)

        if not text:
            text = extract_pdf_text_with_ocr(file_path)

        return {
    "success": True,
    "filename": file.filename,
    "extracted_text": text,
    "preview": text[:1000],
    "is_empty": not bool(text.strip()),
}

    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"PDF processing failed: {exc}") from exc


@app.get("/transactions", response_model=List[TransactionOut])
def transactions(db: Session = Depends(get_db)):
    items = (
        db.query(Transaction)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .all()
    )
    return items


@app.post("/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(payload: TransactionCreate, db: Session = Depends(get_db)):
    new_item = Transaction(
        title=payload.title,
        amount=payload.amount,
        category=payload.category,
        date=payload.date,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item


@app.get("/analytics")
def analytics(db: Session = Depends(get_db)):
    items = (
        db.query(Transaction)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
        .all()
    )

    category_totals = defaultdict(float)
    monthly_totals = defaultdict(float)

    for item in items:
        amount = float(item.amount or 0)

        # Sadece giderleri analytics'e dahil et
        if amount >= 0:
            continue

        expense = abs(amount)
        category = (item.category or "Diger").strip() or "Diger"
        category_totals[category] += expense

        if item.date:
            month_key = item.date.strftime("%Y-%m")
            monthly_totals[month_key] += expense

    categories = [
        {"name": name, "amount": round(total, 2)}
        for name, total in sorted(
            category_totals.items(),
            key=lambda pair: pair[1],
            reverse=True
        )
    ]

    monthly_expenses = [
        {"month": format_month_label(key), "amount": round(monthly_totals[key], 2)}
        for key in sorted(monthly_totals.keys())
    ]

    return {
        "categories": categories,
        "monthly_expenses": monthly_expenses,
    }
@app.get("/prediction")
def prediction(db: Session = Depends(get_db)):
    items = (
        db.query(Transaction)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
        .all()
    )

    monthly_totals = defaultdict(float)

    for item in items:
        amount = float(item.amount or 0)

        # Sadece giderleri tahmin için kullan
        if amount >= 0 or not item.date:
            continue

        month_key = item.date.strftime("%Y-%m")
        monthly_totals[month_key] += abs(amount)

    ordered_months = sorted(monthly_totals.keys())
    monthly_values = [monthly_totals[key] for key in ordered_months]

    if not monthly_values:
        return {
            "predicted_expense": 0,
            "confidence": 0,
            "message": "Henüz yeterli gider verisi yok. Tahmin oluşturmak için işlem eklemelisin."
        }

    if len(monthly_values) == 1:
        predicted_expense = monthly_values[-1]
        confidence = 40
    else:
        recent_values = monthly_values[-3:]
        predicted_expense = sum(recent_values) / len(recent_values)

        if len(monthly_values) >= 3:
            confidence = 80
        else:
            confidence = 65

    predicted_expense = round(predicted_expense, 2)

    message = (
        f"Mevcut harcama trendine gore gelecek ay yaklasik "
        f"{predicted_expense:.2f} TL gider bekleniyor."
    )

    return {
        "predicted_expense": predicted_expense,
        "confidence": confidence,
        "message": message,
    }