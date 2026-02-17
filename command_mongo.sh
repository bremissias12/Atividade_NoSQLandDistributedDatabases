#!/bin/bash

echo "🧹 Limpando collections..."
docker exec -it mongodb-standalone mongosh amazonas_db --eval "db.clientes.drop(); db.eventos.drop();"

echo "📦 Inserindo dados do script..."
docker cp init_data.js mongodb-standalone:/init_data.js

docker exec -it mongodb-standalone mongosh amazonas_db /init_data.js

echo "✅ Dados inseridos com sucesso!"