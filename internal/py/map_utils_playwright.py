import asyncio
import os

from playwright.async_api import Browser, async_playwright


async def _run_batch(jobs: list[tuple], max_workers: int = 4):
    sem = asyncio.Semaphore(max_workers)

    async def shoot(browser: Browser, job: tuple):
        map_file, outfile, width, height, sleep = job
        url = "file://" + os.path.abspath(map_file)
        async with sem:
            page = await browser.new_page()
            await page.set_viewport_size({"width": width, "height": height})
            await page.goto(url)
            try:
                await page.wait_for_load_state("networkidle", timeout=30000)
            except Exception:
                pass  # fallback for WMS/offline maps
            if sleep > 0:
                await asyncio.sleep(sleep)
            data = await page.screenshot()
            await page.close()
        os.makedirs("map-pic", exist_ok=True)
        with open(os.path.join("map-pic", outfile), "wb") as f:
            f.write(data)
        os.remove(map_file)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        await asyncio.gather(*[shoot(browser, j) for j in jobs])
        await browser.close()


def map_to_image(
    map_file: str, outfile: str, width: int, height: int, sleep: float = 2
) -> None:
    """Drop-in Playwright replacement for the Selenium map_to_image."""
    asyncio.run(_run_batch([(map_file, outfile, width, height, sleep)], max_workers=1))


def batch_map_to_image(jobs: list, max_workers: int = 4) -> None:
    """Screenshot multiple maps concurrently.

    Each job: (map_file, outfile, width, height) or (map_file, outfile, width, height, sleep).
    """
    normalized = [j if len(j) == 5 else (*j, 2) for j in jobs]
    asyncio.run(_run_batch(normalized, max_workers))
