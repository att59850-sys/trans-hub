# 🚚 TransportHub

A trusted **transport & logistics marketplace** that connects customers with vetted
transport providers — and lets providers list services and manage bookings.

Built as an **offline-first** single-page web app: no backend or build step required.
All data (users, companies, services, bookings, reviews) is stored locally in the
browser via `localStorage`, seeded with realistic demo content on first load.

> Design: **Style 1 — Modern Material Design** (trust blue + energetic orange).

## ✨ Features

### For customers
- Browse & search providers, filter by service type / verification, sort by rating, reviews, fleet size.
- Rich company profiles with services, transparent pricing, ratings & reviews.
- **Book a service** or **request a custom quote** in a few clicks.
- Save favorites, set your location, track your bookings.
- Write reviews and rate providers.

### For providers (companies)
- Free provider account & public business profile.
- Provider **dashboard**: KPIs, manage services (add / edit / hide / delete), edit profile.
- Receive bookings & quote requests; update booking status (pending → confirmed → completed / cancelled).

### Two roles
- **Customer** — browse, compare and book.
- **Company / Provider** — list services and manage bookings.

## 🆕 New services introduced in this release
On top of the original Freight, Movers, Courier, Coach and Ride categories, this
update adds **five new transport service categories**:

| New service | What it covers |
|-------------|----------------|
| ❄️ **Cold-Chain Logistics** | Refrigerated & temperature-controlled transport (food, pharma) |
| 🏗️ **Heavy Haul & Machinery** | Oversized / abnormal loads with permits & escorts |
| ⚡ **Green / EV Fleet** | Zero-emission electric delivery + carbon reporting |
| 🛩️ **Air & Drone Freight** | Next-flight-out air cargo + last-mile drone delivery |
| ⛴️ **Ferry & Marine** | Ro-Ro vehicle ferries & container marine transfers |

Each ships with seeded demo providers and bookable services.

## ▶️ Run locally
```bash
cd /home/user/webapp
python3 -m http.server 8080
# open the served URL
```

## 🔑 Demo logins
| Role | Email | Password |
|------|-------|----------|
| Customer | `customer@demo.com` | `demo123` |
| Provider | `admin@transglobalfreight.com` | `demo123` |

(Use the in-app **Sign up** to create more accounts. Reset all data by clearing
the browser's local storage for this site.)

## 🗂️ Project structure
```
index.html        # shell: app bar, footer, mount points
styles.css        # Material design system (blue/orange)
js/
  store.js        # localStorage-backed "backend": auth, CRUD, bookings, reviews
  data.js         # service categories (incl. new ones) + seed data
  components.js   # reusable render helpers, modal & toast system
  pages.js        # view renderers (home, browse, profile, dashboard, auth, about)
  app.js          # hash router + all interaction wiring
```

## 🔌 Going cloud
The `js/store.js` layer is intentionally isolated. To connect a real backend
(e.g. Firebase) later, swap its methods for API/SDK calls — the UI and pages
do not depend on `localStorage` directly.
