import urllib.request
import xml.etree.ElementTree as ET
import json
import re
import sys

def get_feed():
    url = "https://lexfridman.com/feed/podcast/"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        xml_data = resp.read()
    root = ET.fromstring(xml_data)
    items = root.find("channel").findall("item")
    
    episodes = []
    for item in items[:6]:
        title = item.find("title").text if item.find("title") is not None else ""
        pubDate = item.find("pubDate").text if item.find("pubDate") is not None else ""
        link = item.find("link").text if item.find("link") is not None else ""
        enclosure = item.find("enclosure")
        audio_url = enclosure.attrib.get("url", "") if enclosure is not None else ""
        audio_len = enclosure.attrib.get("length", "0") if enclosure is not None else "0"
        
        episodes.append({
            "title": title,
            "pubDate": pubDate,
            "link": link,
            "audio_url": audio_url,
            "audio_size_mb": round(int(audio_len) / (1024 * 1024), 1) if audio_len.isdigit() else 0
        })
    return episodes

if __name__ == "__main__":
    episodes = get_feed()
    print(json.dumps(episodes, indent=2, ensure_ascii=False))
