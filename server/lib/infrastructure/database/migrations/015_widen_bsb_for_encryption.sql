-- @description Widens bsb column from CHAR(6) to TEXT to accommodate
--              AES-256-GCM encrypted values (enc:<base64> prefix).
ALTER TABLE bank_accounts ALTER COLUMN bsb TYPE TEXT;
