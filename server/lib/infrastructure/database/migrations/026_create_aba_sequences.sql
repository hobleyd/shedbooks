-- aba_sequences: tracks daily ABA file generation count per entity.
-- Used to produce a unique 3-digit suffix for each ABA file generated on the same day.
-- @entity_id the Auth0 organisation ID owning the sequence
-- @sequence_date the calendar date the sequence applies to
-- @sequence_number number of ABA files generated for this entity on sequence_date
CREATE TABLE aba_sequences (
  entity_id      TEXT    NOT NULL,
  sequence_date  DATE    NOT NULL,
  sequence_number INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (entity_id, sequence_date)
);
