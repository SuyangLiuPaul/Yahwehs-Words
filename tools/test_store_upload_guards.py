import unittest
from windows_store_guard import may_create_draft

class GuardTests(unittest.TestCase):
    def test_no_pending(self):
        self.assertTrue(may_create_draft({"pendingApplicationSubmission": None}))
    def test_preserve_pending(self):
        self.assertFalse(may_create_draft({"pendingApplicationSubmission": {"id": "123"}}))

if __name__ == "__main__":
    unittest.main()
