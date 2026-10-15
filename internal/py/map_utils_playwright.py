import asyncio
import os
from pathlib import Path

from playwright.async_api import Browser, async_playwright
from playwright.async_api import TimeoutError as PlaywrightTimeoutError

DEFAULT_SLEEP = 2  # seconds to wait after network idle, for tiles to paint


async def _run_batch(jobs: list, max_workers: int = 4):
    sem = asyncio.Semaphore(max_workers)

    async def shoot(browser: Browser, job):
        map_file, outfile, width, height, sleep = job
        url = Path(map_file).resolve().as_uri()
        async with sem:
            page = await browser.new_page()
            try:
                await page.set_viewport_size({"width": int(width), "height": int(height)})
                await page.goto(url)
                try:
                    await page.wait_for_load_state("networkidle", timeout=30000)
                except PlaywrightTimeoutError:
                    # e.g. WMS/offline tiles that never go idle
                    print(f"Warning: {outfile}: tiles still loading after 30 s; screenshot may be incomplete")
                if sleep > 0:
                    await asyncio.sleep(sleep)
                data = await page.screenshot()
            finally:
                await page.close()
        os.makedirs(os.path.dirname(os.path.abspath(outfile)), exist_ok=True)
        with open(outfile, "wb") as f:
            f.write(data)
        os.remove(map_file)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        try:
            await asyncio.gather(*[shoot(browser, j) for j in jobs])
        finally:
            await browser.close()


def map_to_image(
    map_file: str, outfile: str, width: int, height: int, sleep: float = DEFAULT_SLEEP
) -> None:
    """Screenshot one saved HTML map to outfile, then delete the HTML."""
    asyncio.run(_run_batch([(map_file, outfile, width, height, sleep)], max_workers=1))


def batch_map_to_image(jobs: list, max_workers: int = 4) -> None:
    """Screenshot several saved HTML maps concurrently in one browser.

    Each job is a list/tuple (map_file, outfile, width, height[, sleep]).
    outfile is written exactly where given (its folder is created);
    map_file is deleted after its screenshot.
    """
    normalized = [tuple(j) if len(j) == 5 else (*j, DEFAULT_SLEEP) for j in jobs]
    asyncio.run(_run_batch(normalized, max_workers))
