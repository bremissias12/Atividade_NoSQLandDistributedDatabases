# NoSQL and Distributed Databases
# Caso de Estudo: MongoDB

## 👥 Integrantes do Grupo

- Breno Missias de Oliveira – RA: 2500036  
- Lucas Silva Santos – RA: 2504094
- Fernanda Sarabando Santolaya – RA: 2502257

## 📌 Descrição do Projeto

A empresa Amazonas do ramo de e-commerce deseja acompanhar os fluxos de cliques de seus clientes, bem como rastrear os produtos que eles compram.Neste momento, a empresa vende livros, CDs e pequenos eletrodomésticos de cozinha apenas, mas provavelmente irá expandir para outros produtos no futuro.

Amazonas quer ser capaz de responder às seguintes perguntas:

Qual é a média de produtos comprados por cliente?
Quais são os 20 produtos mais populares por estado dos clientes?
Qual é o valor médio das vendas por estado do cliente?
Quantos de cada tipo de produto foram vendidos nos últimos 30 dias?
---

## Decisão de Modelagem

Para este cenário, optamos por **duas collections** no MongoDB:

### **1. clientes**
Armazena informações sobre os clientes, como nome, email, estado e data de cadastro.

### **2. eventos**
Armazena eventos de compra, com informações sobre o produto, o cliente vinculado e data/hora da compra.

**Por que duas collections?**

- Os dados de clientes e eventos têm naturezas diferentes e crescem em ritmos distintos.  
- Separar as coleções evita duplicação de dados e melhora a performance de consultas analíticas.  
- Permite vincular eventos a clientes por referência (`cliente_id`) e consultar com agregações quando necessário.  

---

## Estrutura das Collections

### Collection: `clientes`

Campos:

| Campo         | Tipo     | Descrição                      |
|---------------|----------|--------------------------------|
| cliente_id    | String   | ID único do cliente            |
| nome          | String   | Nome completo do cliente       |
| email         | String   | Email do cliente               |
| uf            | String   | Estado do cliente              |
| dt_cadastro   | Date     | Data de cadastro do cliente    |

### Collection: `eventos`

Campos:

| Campo         | Tipo     | Descrição                                 |
|---------------|----------|-------------------------------------------|
| type          | String   | Tipo do evento (ex.: `compras`)           |
| cliente_id    | String   | ID do cliente que realizou a compra       |
| produto       | Object   | Informações do produto comprado           |
| pagina        | String   | Página onde ocorreu o evento (checkout)   |
| dt_compra     | Date     | Data e hora da compra                     |
| metadata      | Object   | Informações adicionais (ex.: pagamento)   |

---

## 📌 Exemplos de Documentos

### Exemplo de Cliente

```json
{
  "cliente_id": "C0001",
  "nome": "Lucas Silva",
  "email": "lucas.silva@example.com",
  "uf": "SP",
  "dt_cadastro": { "$date": "2024-01-15T08:23:00Z" }
}
```

### Exemplo de Evento de Compra

```json
{
  "type": "compras",
  "cliente_id": "C0001",
  "produto": {
    "produto_id": "P1001",
    "categoria": "livro",
    "valor": 49.90
  },
  "pagina": "/checkout",
  "dt_compra": { "$date": "2025-01-10T10:05:00Z" },
  "metadata": {
    "pagamento": "credito"
  }
}
```

## 🚀 Populando o Banco de Dados (MongoDB)

## Depois de subir o container do MongoDB:

### 
```bash
### 1. Copiar o script de inicialização para dentro do container
docker cp init_data.js mongodb-standalone:/init_data.js

### 2. Executar o arquivo de inserts (Não conseguimos realizar o insert pelo arquivo .json, por conta do container, contornamos com o arquivo init_data.js)
docker exec -i mongodb-standalone mongosh amazonas_db --file /init_data.js

### 3. Acessar o Mongo e a base amazonas_db
docker exec -it mongodb-standalone mongosh
use amazonas_db

### 4. Mostrar Collections

show collections

```


## Consultas de Negócio

### Este projeto inclui exemplos de consultas para responder às perguntas de negócio solicitadas:

### 1) Qual é a média de produtos comprados por cliente?

```json
db.eventos.aggregate([
  { $match: { type: "compras" } },
  {
    $group: {
      _id: "$cliente_id",
      totalCompras: { $sum: 1 }
    }
  },
  {
    $group: {
      _id: null,
      mediaComprasPorCliente: { $avg: "$totalCompras" }
    }
  },
  {
    $project: {
      _id: 0,
      mediaComprasPorCliente: 1
    }
  }
]);
```

### 2) Quais são os 20 produtos mais populares por estado dos clientes?

```json
db.eventos.aggregate([
  {
    $lookup: {
      from: "clientes",
      localField: "cliente_id",
      foreignField: "cliente_id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },

  {
    $group: {
      _id: { estado: "$cliente.uf", produto: "$produto.produto_id" },
      totalVendas: { $sum: 1 }
    }
  },

  { $sort: { "_id.estado": 1, totalVendas: -1 } },

  {
    $group: {
      _id: "$_id.estado",
      produtos: {
        $push: {
          produto: "$_id.produto",
          vendas: "$totalVendas"
        }
      }
    }
  },

  {
    $project: {
      estado: "$_id",
      top20Produtos: { $slice: ["$produtos", 20] },
      _id: 0
    }
  }
]);
```

### 3) Qual é o valor médio das vendas por estado do cliente?

```json
db.eventos.aggregate([
  {
    $lookup: {
      from: "clientes",
      localField: "cliente_id",
      foreignField: "cliente_id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },

  {
    $group: {
      _id: "$cliente.uf",
      valorMedio: { $avg: "$produto.valor" }
    }
  },

  {
    $project: {
      estado: "$_id",
      valorMedio: 1,
      _id: 0
    }
  }
]);
```

### 4) Quantos de cada tipo de produto foram vendidos nos últimos 30 dias?

```json
const hoje = new Date();
const trintaDiasAtras = new Date(hoje);
trintaDiasAtras.setDate(trintaDiasAtras.getDate() - 30);

db.eventos.aggregate([
  {
    $match: {
      type: "compras",
      dt_compra: { $gte: trintaDiasAtras }
    }
  },
  {
    $group: {
      _id: "$produto.categoria",
      totalVendidos: { $sum: 1 }
    }
  },
  {
    $project: {
      categoria: "$_id",
      totalVendidos: 1,
      _id: 0
    }
  }
]);
```
