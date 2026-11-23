use std::{collections::HashMap, hash::Hash};

use serde::{Deserialize, Deserializer, Serialize, Serializer, de::Error};

pub fn serialize<S, K, V>(values: &HashMap<K, V>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
    K: Ord + Serialize,
    V: Serialize,
{
    let mut entries: Vec<_> = values.iter().collect();
    entries.sort_unstable_by(|left, right| left.0.cmp(right.0));
    entries.serialize(serializer)
}

pub fn deserialize<'de, D, K, V>(deserializer: D) -> Result<HashMap<K, V>, D::Error>
where
    D: Deserializer<'de>,
    K: Deserialize<'de> + Eq + Hash,
    V: Deserialize<'de>,
{
    let entries = Vec::<(K, V)>::deserialize(deserializer)?;
    let mut values = HashMap::with_capacity(entries.len());
    for (key, value) in entries {
        if values.insert(key, value).is_some() {
            return Err(D::Error::custom("duplicate map key"));
        }
    }
    Ok(values)
}
