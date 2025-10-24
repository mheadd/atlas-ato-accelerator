# ATLAS Demo API

Simple Node.js/Express CRUD API for demonstrating NIST-compliant infrastructure deployment.

## Features

- RESTful API for managing items (Create, Read, Update, Delete)
- PostgreSQL database backend
- Health check endpoint for Kubernetes probes
- Runs as non-root user (NIST AC-6 compliance)
- Environment-based configuration

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check endpoint
- `GET /api/items` - List all items
- `GET /api/items/:id` - Get single item
- `POST /api/items` - Create new item
- `PUT /api/items/:id` - Update item
- `DELETE /api/items/:id` - Delete item

## Environment Variables

- `PORT` - Server port (default: 3000)
- `DB_HOST` - PostgreSQL host
- `DB_PORT` - PostgreSQL port (default: 5432)
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `NODE_ENV` - Environment (development/production)

## Local Development

```bash
npm install
npm run dev
```

## Docker Build

```bash
docker build -t atlas-demo-api:latest .
docker run -p 3000:3000 \
  -e DB_HOST=localhost \
  -e DB_NAME=atlasdemodb \
  -e DB_USER=dbadmin \
  -e DB_PASSWORD=yourpassword \
  atlas-demo-api:latest
```

## Security Features

- Non-root container user (UID 1000)
- Health check endpoint
- Graceful shutdown handling
- Parameterized SQL queries (SQL injection prevention)
- CORS enabled
- Error handling without sensitive information disclosure
