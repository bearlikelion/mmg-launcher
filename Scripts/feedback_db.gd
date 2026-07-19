class_name FeedbackDB
extends RefCounted

# Thin wrapper around godot-sqlite persisting post-play survey responses
# in user://feedback.db.

const TABLE_SQL: String = """
CREATE TABLE IF NOT EXISTS feedback (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	game_title TEXT NOT NULL,
	played_at TEXT NOT NULL,
	duration_seconds INTEGER,
	player_name TEXT,
	enjoyed TEXT,
	fun_rating INTEGER,
	difficulty TEXT,
	play_again TEXT,
	would_purchase TEXT,
	price_point TEXT,
	hit_bugs TEXT,
	comments TEXT
);
"""


# Location of the feedback database in the user data directory
static func db_path() -> String:
	return "user://feedback.db"


# Insert one survey response, creating the table on first use
static func save_response(row: Dictionary) -> bool:
	var db: SQLite = SQLite.new()
	db.path = db_path()
	db.verbosity_level = SQLite.QUIET
	if not db.open_db():
		push_error("FeedbackDB: could not open %s (%s)" % [db_path(), db.error_message])
		return false
	if not db.query(TABLE_SQL):
		push_error("FeedbackDB: create table failed (%s)" % db.error_message)
		db.close_db()
		return false
	var inserted: bool = db.insert_row("feedback", row)
	if not inserted:
		push_error("FeedbackDB: insert failed (%s)" % db.error_message)
	db.close_db()
	return inserted
