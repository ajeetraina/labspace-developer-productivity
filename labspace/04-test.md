# Lab 4 · Test

In this lab you'll add automated tests for the containerized application using **Testcontainers**. The big idea: run your tests against *real* services in throwaway containers, so your tests match production far more closely than mocks ever could.

## 🧪 Understanding Testcontainers

[Testcontainers](https://testcontainers.com/) is a library that gives you lightweight, throwaway instances of databases, message brokers, or anything else that runs in a container. It's ideal for integration testing because:

- It creates **isolated** environments for each test run
- It spins up **actual services** rather than mocks (when you need realism)
- It **cleans up automatically** after tests finish
- It's **language-agnostic** (we'll use the JavaScript implementation)

## Prerequisites

Before running the tests, make sure you have:

- Docker running (it is, in this Labspace)
- *(Optional)* [Testcontainers Desktop](https://testcontainers.com/desktop/) for a visual view of test containers
- Completed **Lab 3 · Develop**

## 🗂️ How the tests are structured

The application uses two kinds of tests:

1. **Unit tests** — exercise individual functions with no external dependencies
2. **Integration tests** — exercise complete features against real dependencies (via Testcontainers)

Key integration test files:

- `containerSupport.js` — manages the container lifecycle for tests
- `kafkaSupport.js` — Kafka testing utilities
- `productCreation.integration.test.js` — tests product creation end to end

## Running the unit tests

Unit tests verify individual functions in isolation — fast feedback, no containers:

```bash
npm run unit-test
```

## Running the integration tests

```bash
npm run integration-test
```

When these run, Testcontainers will:

1. Spin up the required containers (PostgreSQL, Kafka, LocalStack)
2. Run the tests against those real containers
3. Tear the containers down when the run completes

You can watch the containers appear and disappear in Docker Desktop or Testcontainers Desktop:

![Testcontainers in action](https://github.com/user-attachments/assets/9277a932-2227-4cf2-97ab-758e1dd3ea38)

## 🔍 Inside the integration test

### Container setup

The support file starts each dependency in its own container and wires the connection details into environment variables:

```javascript no-run-button
// From containerSupport.js
async function setup() {
  // Start PostgreSQL container
  postgres = await new GenericContainer("postgres:15")
    .withExposedPorts(5432)
    .withEnvironment({ POSTGRES_PASSWORD: "postgres" })
    .start();

  // Start Kafka container
  kafka = await new GenericContainer("confluentinc/cp-kafka:7.4.0")
    .withExposedPorts(9092)
    .withEnvironment({
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://localhost:9092",
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    })
    .start();

  // Start LocalStack (for S3)
  localstack = await new GenericContainer("localstack/localstack:2.2")
    .withExposedPorts(4566)
    .start();

  // Configure environment variables for tests
  process.env.DATABASE_URL = `postgres://postgres:postgres@localhost:${postgres.getMappedPort(5432)}/postgres`;
  process.env.KAFKA_BROKER = `localhost:${kafka.getMappedPort(9092)}`;
  process.env.S3_ENDPOINT = `http://localhost:${localstack.getMappedPort(4566)}`;
}
```

Each test run gets fresh, isolated containers for every service the app depends on.

### Test cases

```javascript no-run-button
// From productCreation.integration.test.js
describe("Product creation", () => {
  it("should publish and return a product when creating a product", async () => {
    const product = { name: "Test Product", upc: "123456789012", price: 9.99 };

    const createdProduct = await productService.createProduct(product);

    expect(createdProduct.id).toBeDefined();
    expect(createdProduct.name).toBe(product.name);
    expect(createdProduct.upc).toBe(product.upc);
    expect(createdProduct.price).toBe(product.price);

    const retrievedProduct = await productService.getProduct(createdProduct.id);
    expect(retrievedProduct).toEqual(createdProduct);
  });

  it("should publish a Kafka message when creating a product", async () => {
    const product = { name: "Kafka Test Product", upc: "123456789013", price: 19.99 };

    await productService.createProduct(product);

    const message = await kafkaConsumer.waitForMessage("products", 5000);
    expect(message).toBeDefined();
    expect(message.action).toBe("product_created");
    expect(message.name).toBe(product.name);
    expect(message.upc).toBe(product.upc);   // 👈 this assertion guards the bug you fixed in Lab 3
    expect(message.price).toBe(product.price);
  });
});
```

Notice the second test asserts that the Kafka message contains the `upc` — exactly the field you fixed in Lab 3. With this test in place, that bug can never silently come back.

These tests verify that products can be created and retrieved, Kafka messages publish correctly, file uploads work, and business rules (like preventing duplicate UPCs) are enforced.

## 💡 Why Testcontainers for integration testing

1. **Realistic** — tests run against actual services, not mocks
2. **Isolated** — each run gets fresh containers
3. **Portable** — identical behavior on any machine with Docker
4. **Parallelizable** — isolated containers allow parallel runs
5. **CI/CD-friendly** — works the same in your pipeline as on your laptop

## 🧰 Common container-based testing patterns

- **Database testing** — a containerized DB with a known schema and seed data
- **Message-queue testing** — verify publishing and consuming with a real broker
- **API testing** — hit API endpoints against containerized dependencies
- **End-to-end testing** — containerize every service to test full workflows

## 🛠️ Troubleshooting

- **Port conflicts** — make sure nothing else is using the same ports
- **Docker connection** — verify Docker is running and reachable
- **Resource limits** — give Docker enough CPU and memory
- **Network issues** — ensure containers can talk to each other

## ✅ Recap

You ran unit and integration tests, saw Testcontainers spin real dependencies up and tear them down automatically, and locked in the Lab 3 fix with a regression test. Next, you'll build the application into an image.
