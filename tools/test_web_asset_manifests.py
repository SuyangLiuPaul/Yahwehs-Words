import base64
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('manifests', Path(__file__).with_name('verify_web_asset_manifests.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.binary = b'flutter-manifest-fixture'
        self.encoded = json.dumps(base64.b64encode(self.binary).decode()).encode()
        self.fonts = json.dumps([{'family':'Roboto','fonts':[{'asset':'assets/Roboto.ttf'}]}]).encode()

    def test_matching_startup_manifests(self):
        self.assertEqual(module.verify_payloads(self.encoded,self.binary,self.fonts), (len(self.binary),1))

    def test_html_spa_fallback_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(b'<!DOCTYPE html>',self.binary,self.fonts)

    def test_mismatched_binary_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(self.encoded,b'old-manifest',self.fonts)

    def test_nonstring_wrapper_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(b'{}',self.binary,self.fonts)

    def test_empty_binary_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(b'""',b'',self.fonts)

    def test_invalid_base64_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(b'"!"',self.binary,self.fonts)

    def test_missing_font_asset_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_payloads(self.encoded,self.binary,b'[{"family":"Roboto","fonts":[{}]}]')

if __name__ == '__main__':
    unittest.main()
