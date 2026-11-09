"""Tests for PDF network timeout and storage error handling.

Run from the backend directory:
    python -m unittest discover -s tests -v
"""

import os
import unittest
from unittest.mock import Mock, patch

import httpx
import requests
from fastapi import HTTPException


# The download helpers import the shared service-role client. Supply harmless
# test-only settings before importing them so this suite does not require a
# developer's local .env file or a live Supabase connection.
_TEST_ENV = {
    "SUPABASE_URL": "https://unit-test-project.supabase.co",
    "SUPABASE_SERVICE_ROLE_KEY": "unit-test-service-role-key",
    "GEMINI_API_KEY": "unit-test-gemini-key",
}
with patch.dict(os.environ, _TEST_ENV):
    from services.pdf_extractor import (
        PDF_CONNECT_TIMEOUT_SECONDS,
        PDF_READ_TIMEOUT_SECONDS,
        _download_external_pdf,
        extract_text_from_bytes,
    )
    from services.private_storage import download_private_file


class ExternalPdfDownloadTests(unittest.TestCase):
    def test_success_uses_bounded_connect_and_read_timeout(self):
        response = Mock()
        response.content = b"%PDF-test-data"
        response.raise_for_status.return_value = None

        with patch("services.pdf_extractor.requests.get", return_value=response) as get:
            content = _download_external_pdf("https://files.example/test.pdf")

        self.assertEqual(content, b"%PDF-test-data")
        self.assertEqual(
            get.call_args.kwargs["timeout"],
            (PDF_CONNECT_TIMEOUT_SECONDS, PDF_READ_TIMEOUT_SECONDS),
        )
        self.assertEqual(PDF_CONNECT_TIMEOUT_SECONDS, 5)
        self.assertEqual(PDF_READ_TIMEOUT_SECONDS, 20)

    def test_timeout_returns_gateway_timeout(self):
        with patch(
            "services.pdf_extractor.requests.get",
            side_effect=requests.exceptions.ReadTimeout("simulated timeout"),
        ):
            with self.assertRaises(HTTPException) as context:
                _download_external_pdf("https://files.example/test.pdf")

        self.assertEqual(context.exception.status_code, 504)
        self.assertIn("timed out", context.exception.detail.lower())

    def test_connection_error_returns_service_unavailable(self):
        with patch(
            "services.pdf_extractor.requests.get",
            side_effect=requests.exceptions.ConnectionError("simulated disconnect"),
        ):
            with self.assertRaises(HTTPException) as context:
                _download_external_pdf("https://files.example/test.pdf")

        self.assertEqual(context.exception.status_code, 503)

    def test_upstream_not_found_returns_404(self):
        response = Mock()
        response.status_code = 404
        response.content = b""
        response.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=Mock(status_code=404)
        )

        with patch("services.pdf_extractor.requests.get", return_value=response):
            with self.assertRaises(HTTPException) as context:
                _download_external_pdf("https://files.example/missing.pdf")

        self.assertEqual(context.exception.status_code, 404)

    def test_unexpected_upstream_status_returns_502(self):
        response = Mock()
        response.status_code = 500
        response.raise_for_status.side_effect = requests.exceptions.HTTPError(
            response=Mock(status_code=500)
        )

        with patch("services.pdf_extractor.requests.get", return_value=response):
            with self.assertRaises(HTTPException) as context:
                _download_external_pdf("https://files.example/failure.pdf")

        self.assertEqual(context.exception.status_code, 502)

    def test_empty_download_returns_422(self):
        response = Mock()
        response.content = b""
        response.raise_for_status.return_value = None

        with patch("services.pdf_extractor.requests.get", return_value=response):
            with self.assertRaises(HTTPException) as context:
                _download_external_pdf("https://files.example/empty.pdf")

        self.assertEqual(context.exception.status_code, 422)

    def test_unreadable_pdf_returns_422(self):
        with self.assertRaises(HTTPException) as context:
            extract_text_from_bytes(b"not a PDF")

        self.assertEqual(context.exception.status_code, 422)


class PrivateStorageDownloadTests(unittest.TestCase):
    def test_storage_timeout_returns_504(self):
        bucket = Mock()
        bucket.download.side_effect = httpx.ReadTimeout("simulated timeout")

        with patch(
            "services.private_storage.supabase_admin.storage.from_",
            return_value=bucket,
        ):
            with self.assertRaises(HTTPException) as context:
                download_private_file("materials/class/test.pdf", "lessons")

        self.assertEqual(context.exception.status_code, 504)

    def test_storage_connection_error_returns_503(self):
        bucket = Mock()
        bucket.download.side_effect = httpx.ConnectError("simulated disconnect")

        with patch(
            "services.private_storage.supabase_admin.storage.from_",
            return_value=bucket,
        ):
            with self.assertRaises(HTTPException) as context:
                download_private_file("materials/class/test.pdf", "lessons")

        self.assertEqual(context.exception.status_code, 503)

    def test_storage_request_error_returns_502(self):
        bucket = Mock()
        bucket.download.side_effect = httpx.RequestError("simulated request failure")

        with patch(
            "services.private_storage.supabase_admin.storage.from_",
            return_value=bucket,
        ):
            with self.assertRaises(HTTPException) as context:
                download_private_file("materials/class/test.pdf", "lessons")

        self.assertEqual(context.exception.status_code, 502)

    def test_empty_storage_object_returns_404(self):
        bucket = Mock()
        bucket.download.return_value = b""

        with patch(
            "services.private_storage.supabase_admin.storage.from_",
            return_value=bucket,
        ):
            with self.assertRaises(HTTPException) as context:
                download_private_file("materials/class/test.pdf", "lessons")

        self.assertEqual(context.exception.status_code, 404)


if __name__ == "__main__":
    unittest.main()
