from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, List
from uuid import uuid4
import hashlib
import os
import re
import secrets

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, ConfigDict, EmailStr
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import (
    SessionLocal,
    engine,
    ensure_transaction_user_id_column,
    ensure_user_login_security_columns,
)
from models.transaction import Base, Transaction
from models.user import User
from models.pdf_upload import PdfUpload, PdfUploadItem

load_dotenv()


app = FastAPI(
    title="AI Finance Coach API",
    version="1.0.0",
)

Base.metadata.create_all(bind=engine)
ensure_transaction_user_id_column()
ensure_user_login_security_columns()

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


def _load_or_create_jwt_secret() -> str:
    env_secret = os.getenv("JWT_SECRET")
    if env_secret:
        return env_secret

    secret_file = os.path.join(os.path.dirname(__file__), ".jwt_secret")
    if os.path.exists(secret_file):
        with open(secret_file, "r", encoding="utf-8") as f:
            saved = f.read().strip()
            if saved:
                return saved

    generated = secrets.token_hex(32)
    with open(secret_file, "w", encoding="utf-8") as f:
        f.write(generated)

    print(
        "UYARI: JWT_SECRET ortam degiskeni/.env dosyasi ayarlanmamis. "
        "Gelistirme icin rastgele bir anahtar uretilip backend/.jwt_secret dosyasina "
        "kaydedildi. Production'da mutlaka JWT_SECRET ortam degiskenini ayarlayin."
    )
    return generated


JWT_SECRET = _load_or_create_jwt_secret()
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Yetkisiz erişim")

    token = credentials.credentials

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=401, detail="Geçersiz token")
        user_id = int(sub)
    except (JWTError, ValueError):
        raise HTTPException(status_code=401, detail="Geçersiz token")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="Kullanıcı bulunamadı")

    return user


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


class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserAuthOut(BaseModel):
    id: int
    name: str
    email: str

    model_config = ConfigDict(from_attributes=True)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserAuthOut


class PdfUploadItemOut(BaseModel):
    id: int
    date: date
    title: str
    amount: Decimal
    category: str
    status: str

    model_config = ConfigDict(from_attributes=True)


class PdfUploadSummary(BaseModel):
    id: int
    filename: str
    uploaded_at: datetime
    total_count: int
    added_count: int
    skipped_count: int
    pending_count: int


class PdfUploadDetail(BaseModel):
    id: int
    filename: str
    uploaded_at: datetime
    items: List[PdfUploadItemOut]


class PdfUploadItemDecision(BaseModel):
    status: str


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
    import pdfplumber

    text_chunks: List[str] = []

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            text_chunks.append(page.extract_text() or "")

    return "\n".join(text_chunks).strip()


def extract_pdf_text_with_ocr(file_path: str) -> str:
    import fitz  # PyMuPDF
    from PIL import Image
    import pytesseract

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


def _parse_statement_date(date_raw: str) -> date | None:
    cleaned = (date_raw or "").strip()
    if not cleaned:
        return None

    parts = cleaned.replace("-", "/").replace(".", "/").split("/")
    if len(parts) != 3:
        return None

    try:
        day = int(parts[0])
        month = int(parts[1])
        year = int(parts[2])
    except ValueError:
        return None

    if year < 100:
        year += 2000

    try:
        return date(year, month, day)
    except ValueError:
        return None


def _parse_statement_amount(amount_raw: str) -> float | None:
    cleaned = (amount_raw or "").strip().upper()
    if not cleaned:
        return None

    cleaned = cleaned.replace("TL", "").replace("TRY", "")
    cleaned = cleaned.replace("USD", "").replace("EUR", "").replace("GBP", "")
    cleaned = cleaned.replace("₺", "").replace(" ", "")

    if "," in cleaned and "." in cleaned:
        if cleaned.rfind(",") > cleaned.rfind("."):
            cleaned = cleaned.replace(".", "").replace(",", ".")
        else:
            cleaned = cleaned.replace(",", "")
    elif "," in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    else:
        cleaned = cleaned.replace(",", "")

    try:
        return float(cleaned)
    except ValueError:
        return None


def _guess_category(title: str) -> str:
    lower = (title or "").lower()

    if any(k in lower for k in ["market", "migros", "carrefour", "a101", "bim", "şok", "sok", "shop", "trendyol", "hepsiburada", "amazon", "akpos"]):
        return "Alışveriş"
    if any(k in lower for k in ["okul", "üniversite", "universite", "egitim", "eğitim", "kurs", "udemy", "kitap", "yks"]):
        return "Eğitim"
    if any(k in lower for k in ["sinema", "netflix", "spotify", "oyun", "eglence", "eğlence", "tiyatro", "steam"]):
        return "Eğlence"
    if any(k in lower for k in ["rest", "kafe", "cafe", "yemek", "yeme", "starbucks", "burger", "kahve"]):
        return "Yeme İçme"
    if any(k in lower for k in ["uber", "taksi", "metro", "otobüs", "otobus", "yakıt", "yakit", "shell", "opet"]):
        return "Ulaşım"
    if any(k in lower for k in ["kira", "elektrik", "su", "doğalgaz", "dogalgaz", "aidat", "internet"]):
        return "Faturalar"
    if any(k in lower for k in ["eczane", "hastane", "doktor", "sağlık", "saglik"]):
        return "Sağlık"

    return "Diğer"


def _build_transaction(tx_date: date, title: str, amount: float) -> dict[str, Any]:
    normalized_title = " ".join((title or "").split()).strip()
    # OCR gürültüsünden kalan 1-2 karakterlik anlamsız parçalar ("we", "sd" gibi)
    # kullanıcıya gösterilecek kadar anlamlı değil; bu durumda nötr bir başlık kullan.
    if len(normalized_title.replace(" ", "")) < 3:
        normalized_title = "Ekstre İşlemi"
    return {
        "date": tx_date.isoformat(),
        "title": normalized_title,
        "amount": round(amount, 2),
        "category": _guess_category(normalized_title),
    }


def parse_transactions_from_text(text: str) -> List[dict[str, Any]]:
    results: List[dict[str, Any]] = []
    seen: set[tuple[str, str, float]] = set()

    line_pattern = re.compile(
        r"^(\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4})\s+(.+?)\s+(?:TL|TRY|USD|EUR|GBP)?\s*([\-+]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))(?:\s+[\-+]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))?$"
    )

    for raw_line in (text or "").splitlines():
        line = " ".join(raw_line.split()).strip()
        if not line:
            continue

        match = line_pattern.match(line)
        if not match:
            continue

        tx_date = _parse_statement_date(match.group(1))
        amount = _parse_statement_amount(match.group(3))
        title = match.group(2).strip()

        if tx_date is None or amount is None:
            continue

        item = _build_transaction(tx_date, title, amount)
        key = (item["date"], item["title"], item["amount"])
        if key in seen:
            continue
        seen.add(key)
        results.append(item)

    return results


_AMOUNT_RE = re.compile(r'^[\-+]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})$')
_DATE_RE = re.compile(r'^\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}$')
_PURE_DIGITS_RE = re.compile(r'^\d+$')
_CURRENCY_CODE_RE = re.compile(r'^(TL|TRY|USD|EUR|GBP)$', re.IGNORECASE)

# Açıklama sütunu tutara en yakın olan sütun olduğu için, tarihten sonraki
# tüm kelimeleri değil, tutara en yakın son birkaç kelimeyi başlık olarak alıyoruz.
# Bu, banka/şube adı gibi tutardan uzak sütunların başlığa karışmasını önler.
_TITLE_TOKEN_LIMIT = 6


def _extract_transactions_from_words(words: list, row_bucket: float) -> List[dict[str, Any]]:
    """Bir sayfadaki kelimeleri (text, top, x0) satırlara grupla ve her satırdan
    tarih + tutar + başlık çıkar. Hem pdfplumber hem OCR (image_to_data) çıktısı
    aynı formatta olduğu için bu fonksiyon her iki kaynak için de ortak kullanılır."""
    rows: dict[float, list] = {}
    for word in words:
        row_key = round(word["top"] / row_bucket) * row_bucket
        rows.setdefault(row_key, []).append(word)

    results: List[dict[str, Any]] = []

    for row_key in sorted(rows.keys()):
        row_words = sorted(rows[row_key], key=lambda w: w["x0"])
        texts = [w["text"] for w in row_words]

        if not texts:
            continue

        # Satırda herhangi bir konumdaki ilk tarihi bul
        date_idx = -1
        tx_date = None
        for idx, t in enumerate(texts):
            if _DATE_RE.match(t):
                maybe = _parse_statement_date(t)
                if maybe is not None:
                    tx_date = maybe
                    date_idx = idx
                    break

        if tx_date is None:
            continue

        # Tarihten sonraki tüm tutarları bul
        amount_indices = [
            i for i, t in enumerate(texts)
            if i > date_idx and _AMOUNT_RE.match(t)
        ]

        if not amount_indices:
            continue

        # İki tutar varsa ilki işlem tutarı, ikincisi bakiye
        chosen_idx = amount_indices[-2] if len(amount_indices) >= 2 else amount_indices[-1]
        amount = _parse_statement_amount(texts[chosen_idx])
        if amount is None:
            continue

        # Tarih ile ilk tutar arasındaki kelimeler aday başlık; tutara en yakın
        # son birkaç tanesi tutulur (açıklama sütunu genelde tutarın hemen solunda)
        first_amt_idx = amount_indices[0]
        title_parts = [
            t for i, t in enumerate(texts)
            if date_idx < i < first_amt_idx
            and not _PURE_DIGITS_RE.match(t)
            and not _CURRENCY_CODE_RE.match(t)
        ]
        if len(title_parts) > _TITLE_TOKEN_LIMIT:
            title_parts = title_parts[-_TITLE_TOKEN_LIMIT:]
        title = " ".join(title_parts).strip() or "Ekstre İşlemi"

        results.append(_build_transaction(tx_date, title, amount))

    return results


def _dedupe_transactions(items: List[dict[str, Any]]) -> List[dict[str, Any]]:
    seen: set[tuple[str, str, float]] = set()
    deduped: List[dict[str, Any]] = []
    for item in items:
        key = (item["date"], item["title"], item["amount"])
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
    return deduped


def parse_transactions_by_words(file_path: str) -> List[dict[str, Any]]:
    """Koordinat tabanlı: gerçek metin katmanı olan çok sütunlu PDF'ler için."""
    import pdfplumber

    all_results: List[dict[str, Any]] = []

    with pdfplumber.open(file_path) as pdf:
        for page in pdf.pages:
            words = page.extract_words(x_tolerance=3, y_tolerance=3)
            if not words:
                continue
            all_results.extend(_extract_transactions_from_words(words, row_bucket=5))

    return _dedupe_transactions(all_results)


def parse_transactions_by_ocr_words(file_path: str) -> List[dict[str, Any]]:
    """Koordinat tabanlı: metin katmanı olmayan (taranmış/ekran görüntüsü) PDF'ler için.
    pytesseract.image_to_string tabloları sütun sütun okuyup satır yapısını bozduğundan,
    burada image_to_data ile her kelimenin konumu alınıp pdfplumber ile aynı satır
    gruplama mantığı uygulanır."""
    import fitz  # PyMuPDF
    from PIL import Image
    import pytesseract

    tesseract_cmd = os.getenv("TESSERACT_CMD", r"C:\Program Files\Tesseract-OCR\tesseract.exe")
    if os.path.exists(tesseract_cmd):
        pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    all_results: List[dict[str, Any]] = []

    with fitz.open(file_path) as doc:
        for page in doc:
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            mode = "RGBA" if pix.alpha else "RGB"
            img = Image.frombytes(mode, [pix.width, pix.height], pix.samples)

            try:
                data = pytesseract.image_to_data(img, lang="tur+eng", output_type=pytesseract.Output.DICT)
            except Exception:
                data = pytesseract.image_to_data(img, lang="eng", output_type=pytesseract.Output.DICT)

            words: list = []
            heights: List[float] = []
            for i, raw_text in enumerate(data.get("text", [])):
                text = (raw_text or "").strip()
                if not text:
                    continue
                words.append({
                    "text": text,
                    "top": float(data["top"][i]),
                    "x0": float(data["left"][i]),
                })
                heights.append(float(data["height"][i]))

            if not words:
                continue

            row_bucket = (sum(heights) / len(heights)) * 0.6 if heights else 10
            all_results.extend(_extract_transactions_from_words(words, row_bucket=row_bucket))

    return _dedupe_transactions(all_results)

@app.get("/")
def home():
    return {"message": "AI Finance Coach API"}


@app.post("/auth/register", response_model=AuthResponse, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    name = payload.name.strip()
    email = payload.email.strip().lower()
    password = payload.password.strip()

    if not name:
        raise HTTPException(status_code=400, detail="Ad alanı zorunludur")

    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Şifre en az 8 karakter olmalıdır")

    user = User(
        name=name,
        email=email,
        password_hash=hash_password(password),
    )

    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Bu e-posta zaten kayıtlı")

    token = create_access_token(user.id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
        },
    }


LOGIN_MAX_ATTEMPTS = 5
LOGIN_LOCKOUT_MINUTES = 15


@app.post("/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    user = db.query(User).filter(User.email == email).first()

    if user is not None and user.locked_until is not None and user.locked_until > now:
        remaining_minutes = max(1, int((user.locked_until - now).total_seconds() // 60) + 1)
        raise HTTPException(
            status_code=429,
            detail=f"Çok fazla başarısız deneme. {remaining_minutes} dakika sonra tekrar dene.",
        )

    if not user or not verify_password(payload.password, user.password_hash):
        if user is not None:
            user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
            if user.failed_login_attempts >= LOGIN_MAX_ATTEMPTS:
                user.locked_until = now + timedelta(minutes=LOGIN_LOCKOUT_MINUTES)
                user.failed_login_attempts = 0
            db.commit()
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı")

    user.failed_login_attempts = 0
    user.locked_until = None
    db.commit()

    token = create_access_token(user.id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
        },
    }


@app.get("/auth/me", response_model=UserAuthOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user


@app.get("/dashboard")
def dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
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


MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB
PDF_MAGIC = b"%PDF-"


def _serialize_pdf_item(item: PdfUploadItem) -> dict[str, Any]:
    return {
        "id": item.id,
        "date": item.date.isoformat(),
        "title": item.title,
        "amount": float(item.amount),
        "category": item.category,
        "status": item.status,
    }


@app.post("/upload-pdf")
async def upload_pdf(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    original_name = os.path.basename(file.filename or "")
    if not original_name.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Sadece PDF dosyaları kabul edilir")

    os.makedirs("uploads", exist_ok=True)
    # Kullanıcının gönderdiği dosya adı hiçbir zaman path olarak kullanılmıyor
    # (path traversal riski); disk üzerinde her zaman rastgele bir isimle saklanır.
    stored_name = f"{uuid4().hex}.pdf"
    file_path = os.path.join("uploads", stored_name)

    try:
        size = 0
        file_hash = hashlib.sha256()
        with open(file_path, "wb") as buffer:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="Dosya boyutu 10MB sınırını aşamaz")
                file_hash.update(chunk)
                buffer.write(chunk)

        with open(file_path, "rb") as check_file:
            header = check_file.read(len(PDF_MAGIC))
        if header != PDF_MAGIC:
            raise HTTPException(status_code=400, detail="Geçerli bir PDF dosyası değil")

        content_hash = file_hash.hexdigest()

        existing_upload = (
            db.query(PdfUpload)
            .filter(PdfUpload.user_id == current_user.id, PdfUpload.file_hash == content_hash)
            .first()
        )

        if existing_upload is not None:
            # Aynı içerik daha önce yüklenmiş: yeniden işlemeden önceki sonucu döndür.
            os.remove(file_path)
            items = [_serialize_pdf_item(item) for item in existing_upload.items]
            return {
                "success": True,
                "duplicate": True,
                "upload_id": existing_upload.id,
                "filename": existing_upload.filename,
                "uploaded_at": existing_upload.uploaded_at.isoformat(),
                "warnings": [],
                "parsed_transactions": items,
                "parsed_count": len(items),
            }

        warnings: List[str] = []
        text = ""

        try:
            text = extract_pdf_text(file_path)
        except Exception as exc:
            warnings.append(f"Metin çıkarma başarısız (pdfplumber): {exc}")

        # Gerçek metin katmanı yoksa (taranmış/ekran görüntüsü PDF), önizleme metni
        # için OCR gerekir. Bu durumda tablo yapısını da OCR'ın kelime konumlarından
        # (image_to_data) çıkarırız; image_to_string satır/sütun sırasını bozar.
        is_scanned = not text.strip()

        if is_scanned:
            try:
                text = extract_pdf_text_with_ocr(file_path)
            except Exception as exc:
                warnings.append(f"OCR kullanılamadı: {exc}")

        parsed_transactions: List[dict[str, Any]] = []

        if not is_scanned:
            try:
                parsed_transactions = parse_transactions_by_words(file_path)
            except Exception as exc:
                warnings.append(f"Kelime tabanlı ayrıştırma kullanılamadı: {exc}")
        else:
            try:
                parsed_transactions = parse_transactions_by_ocr_words(file_path)
            except Exception as exc:
                warnings.append(f"OCR tabanlı tablo ayrıştırma kullanılamadı: {exc}")

        if not parsed_transactions:
            try:
                parsed_transactions = parse_transactions_from_text(text)
            except Exception as exc:
                warnings.append(f"Metin ayrıştırma kullanılamadı: {exc}")

        upload = PdfUpload(
            user_id=current_user.id,
            filename=original_name,
            file_hash=content_hash,
        )
        for candidate in parsed_transactions:
            upload.items.append(
                PdfUploadItem(
                    date=date.fromisoformat(candidate["date"]),
                    title=candidate["title"],
                    amount=candidate["amount"],
                    category=candidate["category"],
                    status="pending",
                )
            )

        db.add(upload)
        db.commit()
        db.refresh(upload)

        items = [_serialize_pdf_item(item) for item in upload.items]

        return {
            "success": True,
            "duplicate": False,
            "upload_id": upload.id,
            "filename": original_name,
            "extracted_text": text,
            "preview": text[:1000],
            "is_empty": not bool(text.strip()),
            "warnings": warnings,
            "parsed_transactions": items,
            "parsed_count": len(items),
        }

    except HTTPException:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise
    except Exception as exc:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise HTTPException(status_code=500, detail=f"PDF işleme hatası: {exc}") from exc


def _get_owned_upload(db: Session, current_user: User, upload_id: int) -> PdfUpload:
    upload = (
        db.query(PdfUpload)
        .filter(PdfUpload.id == upload_id, PdfUpload.user_id == current_user.id)
        .first()
    )
    if upload is None:
        raise HTTPException(status_code=404, detail="Yükleme bulunamadı")
    return upload


@app.get("/pdf-uploads", response_model=List[PdfUploadSummary])
def list_pdf_uploads(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    uploads = (
        db.query(PdfUpload)
        .filter(PdfUpload.user_id == current_user.id)
        .order_by(PdfUpload.uploaded_at.desc(), PdfUpload.id.desc())
        .all()
    )

    summaries = []
    for upload in uploads:
        statuses = [item.status for item in upload.items]
        summaries.append(
            PdfUploadSummary(
                id=upload.id,
                filename=upload.filename,
                uploaded_at=upload.uploaded_at,
                total_count=len(statuses),
                added_count=statuses.count("added"),
                skipped_count=statuses.count("skipped"),
                pending_count=statuses.count("pending"),
            )
        )
    return summaries


@app.get("/pdf-uploads/{upload_id}", response_model=PdfUploadDetail)
def get_pdf_upload(
    upload_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    upload = _get_owned_upload(db, current_user, upload_id)
    return PdfUploadDetail(
        id=upload.id,
        filename=upload.filename,
        uploaded_at=upload.uploaded_at,
        items=list(upload.items),
    )


@app.post("/pdf-uploads/{upload_id}/items/{item_id}/decide", response_model=PdfUploadItemOut)
def decide_pdf_upload_item(
    upload_id: int,
    item_id: int,
    payload: PdfUploadItemDecision,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.status not in ("added", "skipped"):
        raise HTTPException(status_code=400, detail="Gecersiz durum degeri")

    upload = _get_owned_upload(db, current_user, upload_id)
    item = next((candidate for candidate in upload.items if candidate.id == item_id), None)
    if item is None:
        raise HTTPException(status_code=404, detail="İşlem bulunamadı")

    if payload.status == "added":
        if item.status == "added":
            raise HTTPException(status_code=409, detail="Bu işlem zaten eklenmiş")

        new_transaction = Transaction(
            user_id=current_user.id,
            title=item.title,
            amount=item.amount,
            category=item.category,
            date=item.date,
        )
        db.add(new_transaction)
        db.flush()
        item.transaction_id = new_transaction.id
        item.status = "added"
    else:
        # Daha önce eklenmiş bir işlem geri çıkarılıyorsa, oluşturulan gerçek
        # işlem kaydı da silinir; aksi halde işlemler listesinde tutarsızlık olur.
        if item.status == "added" and item.transaction_id is not None:
            linked_transaction = db.get(Transaction, item.transaction_id)
            if linked_transaction is not None and linked_transaction.user_id == current_user.id:
                db.delete(linked_transaction)
            item.transaction_id = None
        item.status = "skipped"

    db.commit()
    db.refresh(item)
    return item


@app.get("/transactions", response_model=List[TransactionOut])
def transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
        .all()
    )
    return items


@app.post("/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(
    payload: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_item = Transaction(
        title=payload.title,
        amount=payload.amount,
        category=payload.category,
        date=payload.date,
        user_id=current_user.id,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item


@app.put("/transactions/{transaction_id}", response_model=TransactionOut)
def update_transaction(
    transaction_id: int,
    payload: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = (
        db.query(Transaction)
        .filter(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
        .first()
    )
    if item is None:
        raise HTTPException(status_code=404, detail="İşlem bulunamadı")

    item.title = payload.title
    item.amount = payload.amount
    item.category = payload.category
    item.date = payload.date

    db.commit()
    db.refresh(item)
    return item


@app.delete("/transactions/{transaction_id}", status_code=204)
def delete_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = (
        db.query(Transaction)
        .filter(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
        .first()
    )
    if item is None:
        raise HTTPException(status_code=404, detail="İşlem bulunamadı")

    # Bu işlem bir PDF içe aktarmasından geldiyse, o kaydın durumunu da senkronize et
    # (aksi halde PDF geçmişinde artık var olmayan bir işleme işaret eden "eklendi" durumu kalır).
    linked_upload_item = (
        db.query(PdfUploadItem)
        .filter(PdfUploadItem.transaction_id == transaction_id)
        .first()
    )
    if linked_upload_item is not None:
        linked_upload_item.status = "skipped"
        linked_upload_item.transaction_id = None

    db.delete(item)
    db.commit()
    return None


@app.get("/analytics")
def analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
        .all()
    )

    category_totals = defaultdict(float)
    monthly_totals = defaultdict(float)

    for item in items:
        amount = float(item.amount or 0)

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
            reverse=True,
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
def prediction(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
        .all()
    )

    monthly_totals = defaultdict(float)

    for item in items:
        amount = float(item.amount or 0)

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
            "message": "Henüz yeterli gider verisi yok. Tahmin oluşturmak için işlem eklemelisin.",
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
        f"Mevcut harcama trendine göre gelecek ay yaklaşık "
        f"{predicted_expense:.2f} TL gider bekleniyor."
    )

    return {
        "predicted_expense": predicted_expense,
        "confidence": confidence,
        "message": message,
    }