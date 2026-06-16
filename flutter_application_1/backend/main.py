from fastapi import FastAPI, UploadFile, File
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware
import pdfplumber
import shutil
import os


app = FastAPI(
    title="AI Finance Coach API",
    version="1.0.0"
)
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------
# HOMEE
# -------------------

@app.get("/")
def home():
    return {
        "message": "AI Finance Coach API"
    }

# -------------------
# DASHBOARDD
# -------------------

@app.get("/dashboard")
def dashboard():
    return {
        "income": 45000,
        "expense": 31200,
        "saving": 13800,
        "risk": "Low"
    }

# -------------------
# PDF UPLOAD
# -------------------

@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):

    os.makedirs("uploads", exist_ok=True)

    file_path = f"uploads/{file.filename}"

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    text = ""

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            text += page.extract_text() or ""

    return {
        "success": True,
        "filename": file.filename,
        "preview": text[:1000]
    }

# -------------------
# TRANSACTIONS
# -------------------

@app.get("/transactions")
def transactions():

    return [
        {
            "id": 1,
            "title": "Migros",
            "amount": -850,
            "category": "Market",
            "date": "2025-07-15"
        },
        {
            "id": 2,
            "title": "Starbucks",
            "amount": -120,
            "category": "Yeme İçme",
            "date": "2025-07-16"
        },
        {
            "id": 3,
            "title": "Maaş",
            "amount": 45000,
            "category": "Gelir",
            "date": "2025-07-01"
        }
    ]

# -------------------
# ANALYTICS
# -------------------

@app.get("/analytics")
def analytics():
    return {
        "categories": [
            {"name": "Market", "amount": 8500},
            {"name": "Yeme İçme", "amount": 3200},
            {"name": "Ulaşım", "amount": 1800},
            {"name": "Eğlence", "amount": 2500}
        ],
        "monthly_expenses": [
            {"month": "Oca", "amount": 12000},
            {"month": "Şub", "amount": 15000},
            {"month": "Mar", "amount": 14000},
            {"month": "Nis", "amount": 18000},
            {"month": "May", "amount": 22000},
            {"month": "Haz", "amount": 31200}
        ]
    }

# -------------------
# PREDICTION
# -------------------

@app.get("/prediction")
def prediction():

    return {
        "predicted_expense": 34500,
        "confidence": 87,
        "message":
        "Mevcut harcama trendine göre gelecek ay yaklaşık 34.500 TL harcama bekleniyor."
    }