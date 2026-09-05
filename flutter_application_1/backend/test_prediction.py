import unittest

from main import (
    _calculate_monthly_forecast,
    _detect_statement_type,
    _normalize_statement_signs,
    parse_transactions_from_text,
)


class ForecastLogicTests(unittest.TestCase):
    def test_rising_trend_increases_prediction(self):
        result = _calculate_monthly_forecast({
            "2024-01": 1200,
            "2024-02": 1400,
            "2024-03": 1600,
            "2024-04": 1800,
        })

        self.assertGreater(result["predicted_expense"], 1500)
        self.assertGreater(result["confidence"], 60)

    def test_empty_dataset_returns_zero(self):
        result = _calculate_monthly_forecast({})
        self.assertEqual(result["predicted_expense"], 0)
        self.assertEqual(result["confidence"], 0)

    def test_bank_debit_titles_are_negative_even_when_amount_is_positive(self):
        items = [
            {"title": "Gider Transfer, Eylem Karakazan", "amount": 30000.0},
            {"title": "Gelir Transfer, Sadık Karakazan", "amount": 5000.0},
            {"title": "Ödeme, Enpara.com kredi kartı ödemesi", "amount": 11501.53},
        ]

        result = _normalize_statement_signs(items, "bank")

        self.assertEqual(result[0]["amount"], -30000.0)
        self.assertEqual(result[1]["amount"], 5000.0)
        self.assertEqual(result[2]["amount"], -11501.53)

    def test_summary_rows_are_not_treated_as_transactions(self):
        text = """
        11.08.2026 Kullanılabilir kart limiti 8605.07
        02.07.2026 Ödeme - Enpara.com Cep Şubesi -11051.53
        """

        result = parse_transactions_from_text(text)
        titles = [item["title"] for item in result]

        self.assertNotIn("Kullanılabilir kart limiti", titles)
        self.assertIn("Ödeme - Enpara.com Cep Şubesi", titles)

    def test_merchant_titles_default_to_expense_sign(self):
        items = [
            {"title": "PİDEM BESİKTAS CADDE ISTANBUL TR", "amount": 135.0},
            {"title": "GÜNEY KEBAP RESTAURANT ISTANBUL TR", "amount": 710.0},
            {"title": "Gelir Transfer, Sadık Karakazan", "amount": 5000.0},
        ]

        result = _normalize_statement_signs(items, "bank")

        self.assertEqual(result[0]["amount"], -135.0)
        self.assertEqual(result[1]["amount"], -710.0)
        self.assertEqual(result[2]["amount"], 5000.0)

    def test_detects_credit_card_statement(self):
        result = _detect_statement_type(
            "Kredi Kartı Ekstresi Dönem Borcu Kullanılabilir Kart Limiti"
        )

        self.assertEqual(result, "credit_card")

    def test_detects_bank_statement(self):
        result = _detect_statement_type("Hesap Hareketleri IBAN Gelen Havale")

        self.assertEqual(result, "bank")


if __name__ == "__main__":
    unittest.main()
