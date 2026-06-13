#!/usr/bin/env python3
"""Thin ClickUp CLI scoped to the VILKA workspace only.

Reads CLICKUP_API_KEY from /Users/ipolotsky/Develop/Aivus/.personal.env.
Writes go into the named lists below (all inside VILKA, space "Shared with me").
Mutations on arbitrary task ids are refused unless the task belongs to VILKA.
This is the only sanctioned way for skills/agents to read and manage ClickUp.
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TEAM_ID = "9012361587"  # VILKA workspace

# Named lists we work with. Default target is development.
LISTS = {
    "conceptualization": "901218647309",  # Dev plan / ✏️ Conceptualization
    "development": "901218647304",  # Dev plan / 🚧 Development
    "bugs": "901218647185",  # NEW PM Logic / Bug Tracking
    "marketing": "901218647303",  # Dev plan / 📈 Marketing & Sales (read-only in practice)
    "brief": "901217318321",  # NEW PM Logic / Brief NEW (legacy)
}
DEFAULT_LIST = "development"

# Valid statuses per list family (for reference / validation hints).
STATUSES = {
    "dev_plan": ["to do", "in progress", "in review", "revisions", "blocked", "complete"],
    "bugs": [
        "Open",
        "triage",
        "in progress",
        "need info",
        "testing",
        "cannot reproduce",
        "not a bug",
        "Closed",
    ],
}

DOC_ID = "8cjvebk-3892"  # AIVUS. Brief. Revisions (strategy/vision doc)

TASK_TYPE_FIELD_ID = "aaac343b-a0ac-42b6-9b35-5a623782002f"
TASK_TYPE_OPTIONS = {
    "Improvement": "30f372cf-33a3-4ab3-aa76-8170fcbac9db",
    "Bug": "cd9c027c-d827-4a20-bb84-586472042815",
    "Feature": "7ef8b2b0-8863-4154-9b8c-dd80f4bf6753",
    "Marketing": "b118406d-6e91-4e07-9f49-64606c3287dd",
}
PRIORITY_MAP = {"urgent": 1, "high": 2, "normal": 3, "low": 4}
ENV_PATH = Path("/Users/ipolotsky/Develop/Aivus/.personal.env")
API_V2 = "https://api.clickup.com/api/v2"
API_V3 = "https://api.clickup.com/api/v3"


def read_token() -> str:
    if not ENV_PATH.exists():
        die(f"env file not found: {ENV_PATH}")
    for line in ENV_PATH.read_text().splitlines():
        if line.startswith("CLICKUP_API_KEY="):
            return line.split("=", 1)[1].strip()
    die("CLICKUP_API_KEY not found in .personal.env")


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def list_id(name: str) -> str:
    if name not in LISTS:
        die(f"unknown list '{name}'. known: {', '.join(LISTS)}")
    return LISTS[name]


def request(method: str, url: str, body: dict | None = None) -> dict:
    token = read_token()
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": token, "Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        die(f"{method} {url} -> {error.code}: {detail}")


def ensure_vilka_task(task_id: str) -> dict:
    task = request("GET", f"{API_V2}/task/{task_id}?include_subtasks=true")
    if task.get("team_id") and str(task["team_id"]) != TEAM_ID:
        die(f"task {task_id} is outside VILKA workspace — refused")
    return task


def out(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def cmd_whoami(_args: argparse.Namespace) -> None:
    data = request("GET", f"{API_V2}/user")
    user = data.get("user", {})
    out({"id": user.get("id"), "username": user.get("username"), "email": user.get("email")})


def cmd_lists(_args: argparse.Namespace) -> None:
    out({"team": TEAM_ID, "default": DEFAULT_LIST, "lists": LISTS, "statuses": STATUSES})


def cmd_list_tasks(args: argparse.Namespace) -> None:
    params = {"page": "0", "subtasks": "true" if args.subtasks else "false"}
    if args.status:
        params["statuses[]"] = args.status
    query = urllib.parse.urlencode(params, doseq=True)
    data = request("GET", f"{API_V2}/list/{list_id(args.list)}/task?{query}")
    tasks = [
        {
            "id": t.get("id"),
            "name": t.get("name"),
            "status": (t.get("status") or {}).get("status"),
            "parent": t.get("parent"),
        }
        for t in data.get("tasks", [])
    ]
    out({"list": args.list, "count": len(tasks), "tasks": tasks})


def cmd_get_task(args: argparse.Namespace) -> None:
    task = ensure_vilka_task(args.id)
    out(
        {
            "id": task.get("id"),
            "name": task.get("name"),
            "status": (task.get("status") or {}).get("status"),
            "parent": task.get("parent"),
            "description": task.get("description"),
            "subtasks": [
                {"id": s.get("id"), "name": s.get("name")} for s in task.get("subtasks", [])
            ],
        }
    )


def cmd_create_task(args: argparse.Namespace) -> None:
    body: dict = {"name": args.name}
    if args.desc:
        body["markdown_content"] = args.desc
    if args.status:
        body["status"] = args.status
    if args.priority:
        body["priority"] = PRIORITY_MAP[args.priority]
    if args.parent:
        ensure_vilka_task(args.parent)
        body["parent"] = args.parent
    if args.type:
        body["custom_fields"] = [
            {"id": TASK_TYPE_FIELD_ID, "value": TASK_TYPE_OPTIONS[args.type]}
        ]
    data = request("POST", f"{API_V2}/list/{list_id(args.list)}/task", body)
    out({"id": data.get("id"), "name": data.get("name"), "url": data.get("url")})


def cmd_update_task(args: argparse.Namespace) -> None:
    ensure_vilka_task(args.id)
    body: dict = {}
    if args.name:
        body["name"] = args.name
    if args.desc:
        body["markdown_content"] = args.desc
    if args.status:
        body["status"] = args.status
    if args.priority:
        body["priority"] = PRIORITY_MAP[args.priority]
    if not body:
        die("nothing to update")
    data = request("PUT", f"{API_V2}/task/{args.id}", body)
    out({"id": data.get("id"), "name": data.get("name")})


def cmd_set_type(args: argparse.Namespace) -> None:
    ensure_vilka_task(args.id)
    request(
        "POST",
        f"{API_V2}/task/{args.id}/field/{TASK_TYPE_FIELD_ID}",
        {"value": TASK_TYPE_OPTIONS[args.type]},
    )
    out({"id": args.id, "type": args.type})


def cmd_set_field(args: argparse.Namespace) -> None:
    ensure_vilka_task(args.id)
    value: object = args.value
    if args.json:
        value = json.loads(args.value)
    request("POST", f"{API_V2}/task/{args.id}/field/{args.field_id}", {"value": value})
    out({"id": args.id, "field": args.field_id})


def cmd_comment(args: argparse.Namespace) -> None:
    ensure_vilka_task(args.id)
    data = request("POST", f"{API_V2}/task/{args.id}/comment", {"comment_text": args.text})
    out({"comment_id": data.get("id")})


def cmd_delete_task(args: argparse.Namespace) -> None:
    ensure_vilka_task(args.id)
    request("DELETE", f"{API_V2}/task/{args.id}")
    out({"deleted": args.id})


def cmd_list_fields(args: argparse.Namespace) -> None:
    data = request("GET", f"{API_V2}/list/{list_id(args.list)}/field")
    fields = []
    for f in data.get("fields", []):
        options = [
            o.get("name") or o.get("label")
            for o in (f.get("type_config") or {}).get("options", [])
        ]
        fields.append(
            {"type": f.get("type"), "name": f.get("name"), "id": f.get("id"), "options": options}
        )
    out({"list": args.list, "fields": fields})


def cmd_create_page(args: argparse.Namespace) -> None:
    doc = args.doc or DOC_ID
    content = Path(args.content_file).read_text() if args.content_file else args.content
    body = {
        "name": args.name,
        "content": content,
        "content_format": "text/md",
        "sub_title": "",
    }
    data = request("POST", f"{API_V3}/workspaces/{TEAM_ID}/docs/{doc}/pages", body)
    out({"id": data.get("id"), "name": data.get("name"), "doc": doc})


def cmd_update_page(args: argparse.Namespace) -> None:
    doc = args.doc or DOC_ID
    content = Path(args.content_file).read_text() if args.content_file else args.content
    body = {"content": content, "content_format": "text/md", "content_edit_mode": "replace"}
    if args.name:
        body["name"] = args.name
    request("PUT", f"{API_V3}/workspaces/{TEAM_ID}/docs/{doc}/pages/{args.page}", body)
    out({"updated": args.page, "doc": doc})


def cmd_get_page(args: argparse.Namespace) -> None:
    doc = args.doc or DOC_ID
    data = request(
        "GET",
        f"{API_V3}/workspaces/{TEAM_ID}/docs/{doc}/pages/{args.page}?content_format=text%2Fmd",
    )
    out({"id": data.get("id"), "name": data.get("name"), "content": data.get("content")})


def cmd_list_pages(args: argparse.Namespace) -> None:
    doc = args.doc or DOC_ID
    data = request(
        "GET",
        f"{API_V3}/workspaces/{TEAM_ID}/docs/{doc}/pages?content_format=text%2Fmd&max_page_depth=-1",
    )
    pages = data if isinstance(data, list) else data.get("pages", [])

    def flatten(items: list, depth: int = 0) -> list:
        result = []
        for item in items:
            result.append({"id": item.get("id"), "name": item.get("name"), "depth": depth})
            result.extend(flatten(item.get("pages", []), depth + 1))
        return result

    out({"doc": doc, "pages": flatten(pages)})


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ClickUp CLI scoped to VILKA workspace")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("whoami").set_defaults(func=cmd_whoami)
    sub.add_parser("lists").set_defaults(func=cmd_lists)

    p = sub.add_parser("list-tasks")
    p.add_argument("--list", default=DEFAULT_LIST, choices=list(LISTS))
    p.add_argument("--status")
    p.add_argument("--subtasks", action="store_true")
    p.set_defaults(func=cmd_list_tasks)

    p = sub.add_parser("get-task")
    p.add_argument("id")
    p.set_defaults(func=cmd_get_task)

    p = sub.add_parser("create-task")
    p.add_argument("--list", default=DEFAULT_LIST, choices=list(LISTS))
    p.add_argument("--name", required=True)
    p.add_argument("--desc", default="")
    p.add_argument("--status")
    p.add_argument("--type", choices=list(TASK_TYPE_OPTIONS))
    p.add_argument("--priority", choices=list(PRIORITY_MAP))
    p.add_argument("--parent")
    p.set_defaults(func=cmd_create_task)

    p = sub.add_parser("update-task")
    p.add_argument("id")
    p.add_argument("--name")
    p.add_argument("--desc")
    p.add_argument("--status")
    p.add_argument("--priority", choices=list(PRIORITY_MAP))
    p.set_defaults(func=cmd_update_task)

    p = sub.add_parser("set-type")
    p.add_argument("id")
    p.add_argument("--type", required=True, choices=list(TASK_TYPE_OPTIONS))
    p.set_defaults(func=cmd_set_type)

    p = sub.add_parser("set-field")
    p.add_argument("id")
    p.add_argument("--field-id", dest="field_id", required=True)
    p.add_argument("--value", required=True)
    p.add_argument("--json", action="store_true", help="parse --value as JSON")
    p.set_defaults(func=cmd_set_field)

    p = sub.add_parser("comment")
    p.add_argument("id")
    p.add_argument("--text", required=True)
    p.set_defaults(func=cmd_comment)

    p = sub.add_parser("delete-task")
    p.add_argument("id")
    p.set_defaults(func=cmd_delete_task)

    p = sub.add_parser("list-fields")
    p.add_argument("--list", default=DEFAULT_LIST, choices=list(LISTS))
    p.set_defaults(func=cmd_list_fields)

    p = sub.add_parser("create-page")
    p.add_argument("--name", required=True)
    p.add_argument("--content", default="")
    p.add_argument("--content-file", dest="content_file")
    p.add_argument("--doc")
    p.set_defaults(func=cmd_create_page)

    p = sub.add_parser("update-page")
    p.add_argument("page")
    p.add_argument("--name")
    p.add_argument("--content", default="")
    p.add_argument("--content-file", dest="content_file")
    p.add_argument("--doc")
    p.set_defaults(func=cmd_update_page)

    p = sub.add_parser("get-page")
    p.add_argument("page")
    p.add_argument("--doc")
    p.set_defaults(func=cmd_get_page)

    p = sub.add_parser("list-pages")
    p.add_argument("--doc")
    p.set_defaults(func=cmd_list_pages)

    return parser


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
