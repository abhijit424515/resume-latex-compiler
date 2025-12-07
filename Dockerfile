FROM registry.gitlab.com/islandoftex/images/texlive:latest-full
WORKDIR /workspace

# Install fonts at runtime when volume is mounted
# Fonts should be mounted at /workspace/fonts
RUN printf '#!/bin/bash\n\
if [ -d "/workspace/fonts" ] && [ "$(ls -A /workspace/fonts 2>/dev/null)" ]; then\n\
  cp -r /workspace/fonts/* /usr/local/share/fonts/ 2>/dev/null || true\n\
  fc-cache -f -v >/dev/null 2>&1 || true\n\
fi\n\
exec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Default command - can be overridden
CMD ["latexmk", "-xelatex", "-interaction=nonstopmode"]