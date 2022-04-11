##[
    Module which contains helper procs for easier json usage.
]##

import std/[json, tables]

func hasField*(self: JsonNode, field: string, kind: JsonNodeKind): bool =
    result = self.kind == JsonNodeKind.JObject and self.fields.hasKey(field) and self.fields[field].kind == kind

func getIntSafe*(self: JsonNode, field: string, default: int = 0): int =
    result = default
    if self.hasField(field, JsonNodeKind.JInt):
        result = self.fields[field].getInt(default)

func getFloatSafe*(self: JsonNode, field: string, default: float = 0.0): float =
    result = default
    if self.hasField(field, JsonNodeKind.JFloat):
        result = self.fields[field].getFloat(default)

func getStringSafe*(self: JsonNode, field: string, default: string = ""): string =
    result = default
    if self.hasField(field, JsonNodeKind.JString):
        result = self.fields[field].getStr(default)
