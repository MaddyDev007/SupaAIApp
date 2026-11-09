"""Tests for required and optional backend environment configuration."""

import unittest

from config import build_settings


class BuildSettingsTests(unittest.TestCase):
    def setUp(self):
        self.valid_env = {
            "SUPABASE_URL": "https://example-project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "test-service-role-key",
            "GEMINI_API_KEY": "test-gemini-key",
        }

    def test_accepts_valid_required_configuration(self):
        settings = build_settings(self.valid_env)

        self.assertEqual(
            settings.supabase_url,
            "https://example-project.supabase.co",
        )
        self.assertEqual(
            settings.supabase_service_role_key,
            "test-service-role-key",
        )
        self.assertEqual(settings.gemini_api_key, "test-gemini-key")

    def test_cohere_is_optional(self):
        settings = build_settings(self.valid_env)
        self.assertIsNone(settings.cohere_api_key)

    def test_accepts_optional_cohere_key(self):
        env = {**self.valid_env, "COHERE_API_KEY": "test-cohere-key"}
        settings = build_settings(env)
        self.assertEqual(settings.cohere_api_key, "test-cohere-key")

    def test_reports_all_missing_required_variables(self):
        with self.assertRaises(RuntimeError) as context:
            build_settings({})

        message = str(context.exception)
        self.assertIn("SUPABASE_URL", message)
        self.assertIn("SUPABASE_SERVICE_ROLE_KEY", message)
        self.assertIn("GEMINI_API_KEY", message)

    def test_rejects_whitespace_only_values(self):
        env = {
            "SUPABASE_URL": " ",
            "SUPABASE_SERVICE_ROLE_KEY": "  ",
            "GEMINI_API_KEY": "\t",
        }

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertIn("missing or empty", str(context.exception))

    def test_rejects_invalid_supabase_url(self):
        env = {**self.valid_env, "SUPABASE_URL": "not-a-url"}

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertIn("invalid format: SUPABASE_URL", str(context.exception))

    def test_rejects_placeholder_api_key(self):
        env = {**self.valid_env, "GEMINI_API_KEY": "your_gemini_api_key"}

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertIn("GEMINI_API_KEY", str(context.exception))

    def test_rejects_placeholder_supabase_url(self):
        env = {
            **self.valid_env,
            "SUPABASE_URL": "https://your-project.supabase.co",
        }

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertIn("SUPABASE_URL", str(context.exception))

    def test_rejects_unresolved_blueprint_placeholder(self):
        env = {**self.valid_env, "GEMINI_API_KEY": "${GEMINI_API_KEY}"}

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertIn("GEMINI_API_KEY", str(context.exception))

    def test_error_never_discloses_secret_values(self):
        env = {
            "SUPABASE_URL": "https://example-project.supabase.co",
            "SUPABASE_SERVICE_ROLE_KEY": "super-secret-value",
            "GEMINI_API_KEY": "",
        }

        with self.assertRaises(RuntimeError) as context:
            build_settings(env)

        self.assertNotIn("super-secret-value", str(context.exception))


if __name__ == "__main__":
    unittest.main()
