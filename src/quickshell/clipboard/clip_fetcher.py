#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import time
import threading
import concurrent.futures
import urllib.parse
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.svg', '.ico', '.tiff', '.tif', '.avif', '.jxl'}

def check_image_path(text):
    if not text:
        return None
    text = text.strip()
    candidates = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("file://"):
            path = urllib.parse.unquote(urllib.parse.urlparse(line).path)
            candidates.append(path)
        elif line.startswith("/") or line.startswith("~"):
            candidates.append(os.path.expanduser(line))
    
    if "file://" in text:
        for part in text.split():
            if part.startswith("file://"):
                path = urllib.parse.unquote(urllib.parse.urlparse(part).path)
                candidates.append(path)

    for path in candidates:
        try:
            if os.path.isfile(path):
                ext = os.path.splitext(path)[1].lower()
                if ext in IMAGE_EXTENSIONS:
                    return path
        except Exception:
            pass
    return None

def cleanup_cache(all_lines, cache_dir):
    valid_ids = {line.split('\t', 1)[0] for line in all_lines[:100] if '\t' in line}
    try:
        for f in os.listdir(cache_dir):
            if f.endswith('.png'):
                iid = f.replace('.png', '')
                if iid not in valid_ids:
                    try:
                        os.remove(os.path.join(cache_dir, f))
                    except Exception:
                        pass
    except Exception:
        pass

def decode_image(iid, img_path):
    if not os.path.exists(img_path):
        try:
            with open(img_path, "wb") as f:
                subprocess.run(["cliphist", "decode", iid], stdout=f, check=True)
        except Exception:
            if os.path.exists(img_path):
                os.remove(img_path)

def get_pinned_items(cache_dir):
    pinned_file = os.path.join(cache_dir, "pinned.json")
    if os.path.exists(pinned_file):
        try:
            with open(pinned_file, 'r') as f:
                return json.load(f)
        except Exception:
            return []
    return []

def toggle_pin(iid, cache_dir):
    pinned_file = os.path.join(cache_dir, "pinned.json")
    pinned = get_pinned_items(cache_dir)
    if iid in pinned:
        pinned.remove(iid)
    else:
        pinned.append(iid)
    with open(pinned_file, 'w') as f:
        json.dump(pinned, f)

def copy_item(iid, is_pinned=False, cache_dir=None):
    try:
        proc = subprocess.run(["cliphist", "decode", str(iid)], capture_output=True)
        raw = proc.stdout
        if not raw:
            return
        try:
            text = raw.decode("utf-8")
            lines = [line.strip() for line in text.splitlines() if line.strip()]
            file_uris = [line for line in lines if line.startswith("file://")]
            if file_uris:
                payload = "\r\n".join(file_uris) + "\r\n"
                subprocess.run(["wl-copy", "-t", "text/uri-list"], input=payload.encode("utf-8"))
            else:
                subprocess.run(["wl-copy"], input=raw)
        except UnicodeDecodeError:
            subprocess.run(["wl-copy"], input=raw)

        if is_pinned and cache_dir:
            time.sleep(0.05)
            try:
                res = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
                lines = res.stdout.splitlines()
                if lines and "\t" in lines[0]:
                    new_id = lines[0].split("\t", 1)[0]
                    pinned_file = os.path.join(cache_dir, "pinned.json")
                    pinned = get_pinned_items(cache_dir)
                    if new_id not in pinned:
                        pinned.append(new_id)
                        with open(pinned_file, 'w') as f:
                            json.dump(pinned, f)
            except Exception:
                pass
    except Exception:
        pass

def delete_item(iid, cache_dir):
    try:
        result = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
        for line in result.stdout.splitlines():
            if line.startswith(f"{iid}\t"):
                subprocess.run(["cliphist", "delete"], input=line.encode('utf-8'))
                break
        
        img_path = os.path.join(cache_dir, f"{iid}.png")
        if os.path.exists(img_path):
            os.remove(img_path)
            
        pinned = get_pinned_items(cache_dir)
        if iid in pinned:
            toggle_pin(iid, cache_dir)
            
    except Exception:
        pass

def get_cliphist():
    cache_dir = os.environ.get("QS_CACHE_CLIPBOARD", os.path.expanduser("~/.cache/quickshell/clipboard"))
    if len(sys.argv) > 3:
        cache_dir = sys.argv[-1]
        
    os.makedirs(cache_dir, exist_ok=True)

    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == "wipe":
            subprocess.run(["cliphist", "wipe"])
            try:
                for f in os.listdir(cache_dir):
                    os.remove(os.path.join(cache_dir, f))
            except Exception:
                pass
            print("[]")
            return
        elif action == "copy" and len(sys.argv) > 2:
            is_pinned = len(sys.argv) > 3 and sys.argv[3] == "1"
            if len(sys.argv) > 4:
                cache_dir = sys.argv[4]
            copy_item(sys.argv[2], is_pinned=is_pinned, cache_dir=cache_dir)
            return
        elif action == "delete" and len(sys.argv) > 2:
            delete_item(sys.argv[2], cache_dir)
            return
        elif action == "pin" and len(sys.argv) > 2:
            toggle_pin(sys.argv[2], cache_dir)
            return

    offset = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
    limit = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 12 
    
    try:
        result = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
        all_lines = result.stdout.splitlines()
        lines = all_lines[offset:offset+limit]
        
        if offset == 0:
            threading.Thread(target=cleanup_cache, args=(all_lines, cache_dir), daemon=True).start()
    except Exception:
        print("[]")
        return

    pinned_ids = get_pinned_items(cache_dir)
    items = []
    decode_tasks = []

    for line in lines:
        if not line: continue
        parts = line.split('\t', 1)
        if len(parts) != 2: continue
        
        iid, content = parts[0], parts[1]
        item_type = "text"
        display_content = content.strip()

        if "[[ binary data" in content:
            item_type = "image"
            img_path = os.path.join(cache_dir, f"{iid}.png")
            decode_tasks.append((iid, img_path))
            display_content = img_path
        else:
            img_file = check_image_path(content)
            dec = None
            if not img_file and ("nautilus" in content or "clipboard" in content or content == "copy" or content.startswith("file:") or "file://" in content):
                try:
                    dec = subprocess.run(["cliphist", "decode", iid], capture_output=True, text=True, errors='ignore').stdout
                    img_file = check_image_path(dec)
                except Exception:
                    pass
            if img_file:
                item_type = "image"
                display_content = img_file
            else:
                check_text = dec if dec is not None else content
                if "file://" in check_text:
                    item_type = "file"
                    for l in check_text.splitlines():
                        l = l.strip()
                        if l.startswith("file://"):
                            path = urllib.parse.unquote(urllib.parse.urlparse(l).path)
                            fname = os.path.basename(path.rstrip('/'))
                            display_content = fname if fname else path
                            break
                        elif "file://" in l:
                            for part in l.split():
                                if part.startswith("file://"):
                                    path = urllib.parse.unquote(urllib.parse.urlparse(part).path)
                                    fname = os.path.basename(path.rstrip('/'))
                                    display_content = fname if fname else path
                                    break
                            if display_content != content.strip():
                                break
        items.append({
            "id": iid,
            "content": display_content,
            "type": item_type,
            "pinned": iid in pinned_ids
        })

    if decode_tasks:
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, len(decode_tasks))) as executor:
            for iid, img_path in decode_tasks:
                executor.submit(decode_image, iid, img_path)

    print(json.dumps(items))

if __name__ == "__main__":
    get_cliphist()
