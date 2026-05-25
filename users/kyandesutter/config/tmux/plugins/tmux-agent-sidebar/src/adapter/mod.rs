pub mod claude;
pub mod codex;

pub(crate) fn json_str<'a>(val: &'a serde_json::Value, key: &str) -> &'a str {
    val.get(key).and_then(|v| v.as_str()).unwrap_or("")
}
