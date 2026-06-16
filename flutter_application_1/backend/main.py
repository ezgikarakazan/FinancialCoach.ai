from fastapi import FastAPI, UploadFile, File
from datetime import datetime

app = FastAPI(
    title="AI Finance Coach API",
    version="1.0.0"
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

    return {
        "success": True,
        "filename": file.filename,
        "message": "PDF başarıyla yüklendi"
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
        "categories": {
            "Market": 8500,
            "Yeme İçme": 3200,
            "Ulaşım": 1800,
            "Eğlence": 2500
        },

        "monthly_expenses": [
            {"month": "Ocak", "amount": 12000},
            {"month": "Şubat", "amount": 15000},
            {"month": "Mart", "amount": 14000},
            {"month": "Nisan", "amount": 18000},
            {"month": "Mayıs", "amount": 22000},
            {"month": "Haziran", "amount": 31200}
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