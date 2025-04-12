# Getting Started with the Jobber App

## 1. Create a `.env` File

Create a `.env` file by copying the contents of `.env.dev`:

```env
VITE_NODE_ENV=development
VITE_BASE_ENDPOINT=http://localhost:4000
VITE_CLIENT_ENDPOINT=http://localhost:3000
VITE_STRIPE_KEY=
VITE_ELASTIC_APM_SERVER=http://localhost:8200
```

---

## 2. Set Up the Frontend Application

Run the following commands:

```bash
npm install
npm run build
npm run start
```

---

## 3. Troubleshooting Build Issues

### ❌ Issue 1: TypeScript Errors

```ts
src/shared/utils/static-data.ts:14:14 - error TS2739: Type '{ ... }' is missing the following properties from type 'IAuthUser': browserName, deviceType

src/store/store.ts:2:30 - error TS2307: Cannot find module '@reduxjs/toolkit/dist/configureStore'
```

✅ **Solution:** Add this to `static-data.ts`:

```ts
export const initialAuthUserValues: IAuthUser = {
  profilePublicId: null,
  country: null,
  createdAt: null,
  email: null,
  emailVerificationToken: null,
  emailVerified: null,
  id: null,
  passwordResetExpires: null,
  passwordResetToken: null,
  profilePicture: null,
  updatedAt: null,
  username: null,
  browserName: null,
  deviceType: null,
};
```

---

### ❌ Issue 2: Property 'data' does not exist on type 'Action'

```ts
src/features/auth/components/VerifyOTP.tsx:50:39 - error TS2339
src/features/auth/components/VerifyOTP.tsx:54:41 - error TS2339
```

✅ **Solution:** Update `VerifyOTP.tsx`:

```ts
const buyerResponse =
  await buyerApi.endpoints.getCurrentBuyerByUsername.initiate();
if ("data" in buyerResponse && buyerResponse.data) {
  const buyerData = buyerResponse.data as { buyer: unknown };
  dispatch(addBuyer(buyerData.buyer));
}

const sellerResponse = await sellerApi.endpoints.getSellerByUsername.initiate(
  `${result.user?.username}`
);
if ("data" in sellerResponse && sellerResponse.data) {
  const sellerData = sellerResponse.data as { seller: unknown };
  dispatch(addSeller(sellerData.seller));
}
```

---

## 4. Docker Compose Setup

### 🧹 Cleanup

Delete existing Docker volumes:

```bash
rm -rf volumes/docker-volumes
```

### 🛠 Configuration Changes

- Replace all `../server` paths with `../microservices`
- Rename container `order_container` to `review_container`:

```yaml
review:
  container_name: review_container
```

- Remove the following line from MySQL service:

```yaml
command: --default-authentication-plugin=mysql_native_password
```

---

## 5. Elasticsearch Setup

### Steps:

1. Start the Elasticsearch container:

```bash
docker compose up -d elasticsearch
```

2. In Docker Desktop, select `elasticsearch_container`
3. Open the **Exec** tab and change the Kibana system password:

```bash
curl -s -X POST -u <superuser>:<password> -H "Content-Type: application/json" http://localhost:<elasticsearch_PORT>/_security/user/kibana_system/_password -d "{\"password\": \"<kibana_password>\"}"
```

**Example:**

```bash
curl -s -X POST -u elastic:admin1234 -H "Content-Type: application/json" http://localhost:9200/_security/user/kibana_system/_password -d "{\"password\": \"kibana\"}"
```

4. Verify the utility:

```bash
cd bin
ls
```

5. Generate a service account token:

```bash
elasticsearch_service_token create <namespace>/<service-name> <kibana-service-name>
```

**Example:**

```bash
elasticsearch_service_token create elastic/kibana kibana
```

6. Add the generated token to Kibana’s environment:

```env
ELASTICSEARCH_SERVICEACCOUNT_TOKEN=AAEAAWVsYXN0aWMva2liYW5hL2tpYmFuYTpQbm5tTkVlZFRhV1NBdXJraUJVRk9B
```

7. Start Kibana:

```bash
docker compose up -d kibana
```

---

## 6. Start Supporting Services

```bash
docker compose up -d redis mongodb mysql postgres rabbitmq
```

---

## 7. Access Kibana

Visit: [http://localhost:5601/app/home#/](http://localhost:5601/app/home#/)

**Login with:**

- **Username:** `elastic`
- **Password:** `admin1234`

---

## 8. Set Up Microservices

### Shared `jobber-shared` NPM Package

- Contains common code used across microservices.
- Published to **GitHub Package Registry**.

### Publishing Steps:

1. Clone or download the repo.
2. Delete `.git`:

```bash
rm -rf .git
```

3. Reinitialize Git:

```bash
git init
```

4. Create a GitHub personal access token.
5. Export the token:

```bash
export NPM_TOKEN=<your-token>
```

6. Update `.npmrc`:

```sh
@<github-username>:registry=https://npm.pkg.github.com/<github-username>
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

7. Update `package.json`:

- `name`: `@<github-username>/<library-name>`
- `author`, `repository.url`

8. Update `.github/workflows/publish.yml`:

- Replace `<your-github-username>`
- Update Node.js version if needed

9. Push to GitHub — GitHub Actions will publish the package.

### ⚠️ Reminder

Update version number in `package.json` before each publish.

---

## 9. Microservice Setup

- Update Node.js version in `Dockerfile` and `Dockerfile.dev`
- Ensure shared library is published
- Copy `.npmrc` with token set
- Replace `@uzochukwueddie/jobber-shared` with your package name
- Run `npm install`
- Copy `.env.dev` to `.env`
- Run with `npm run dev`
- Install `nodemon` if desired

### Docker Image Steps

1. Login to [Docker Hub](https://hub.docker.com)
2. Login in terminal
3. Build & push:

```bash
docker build -t <your-dockerhub-username>/jobber-review .
docker tag <your-dockerhub-username>/jobber-review <your-dockerhub-username>/jobber-review:stable
docker push <your-dockerhub-username>/jobber-review:stable
```

Repeat for:

- review service
- order service
- chat service
- gig service
- users service
- auth service
- notification service

---

## 10. Kubernetes Setup (Minikube)

### K8s Object Commands

```bash
kubectl apply -f .                # Apply all YAML files
kubectl apply -f <file>.yaml      # Apply a specific file
```

### Start Minikube

Max resources:

```bash
minikube start --memory=max --cpus=max
```

Specific resources:

```bash
minikube start --cpus 3 --memory 3072
```

### Change Kibana User Password

```bash
curl -s -X POST -u elastic:admin1234 -H "Content-Type: application/json" http://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibana\"}"
```

### Create Kibana Service Token

```bash
bin/elasticsearch-service-tokens create elastic/kibana jobber-kibana
```

### Port Forwarding

```bash
kubectl -n <namespace> port-forward <pod-name> <forward-port>:<container-port>
```

---
