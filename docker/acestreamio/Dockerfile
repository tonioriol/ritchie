FROM node:20-bookworm-slim

WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copy the full addon source (including posters)
COPY . .

ENV NODE_ENV=production

# The runtime port is controlled by $PORT (we set it via the Helm chart)
EXPOSE 7000

CMD ["npm", "start"]

