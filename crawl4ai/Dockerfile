FROM unclecode/crawl4ai:0.9.3

# Set a global path for Playwright browsers so all users can access them
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright

# Switch to root to install chromium in a dedicated layer
USER root
RUN mkdir -p /opt/playwright && \
    python -m playwright install chromium && \
    chmod -R 755 /opt/playwright

# Revert to the user used in the base image
USER appuser

# Use the original base image startup command
CMD ["supervisord", "-c", "supervisord.conf"]
