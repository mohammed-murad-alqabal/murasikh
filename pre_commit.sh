#!/bin/bash
# Pre-commit checks
ruff check backend/app
cd backend && pytest tests
