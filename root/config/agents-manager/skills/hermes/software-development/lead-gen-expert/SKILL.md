---
name: lead-gen-expert
version: 2.0.0
description: "Lead Generation Agent - Discovers businesses needing websites via Google Maps, scores them, saves to CRM"
metadata:
  emoji: "🎯"
  requires:
    bins: ["docker", "playwright"]
---

# Lead Gen Expert 🎯

---

## Mission

Find businesses that NEED websites → Score them → Save to CRM

---

## Workflow

### Step 1: Discover via Google Maps
Search businesses by category and location.

### Step 2: Extract Data
- Business name, Phone number, Address
- Category, Rating, Reviews count
- Website URL (if exists)

### Step 3: Score Lead (0-100)

### Step 4: Save to CRM

---

## Expanded Scoring Algorithm (0-100)

### BASE SCORE: 50

#### ADD POINTS

| Factor | Points | Reason |
|--------|--------|--------|
| **No website** | +30 | Needs one ASAP |
| **Website = none/social only** | +25 | Not a real site |
| **Static HTML (no CMS)** | +20 | Outdated tech |
| **No mobile optimization** | +15 | Google penalizes |
| **Slow loading (>5s)** | +15 | Bad UX |
| **No contact form** | +10 | Can't convert |
| **No online booking** | +10 | Missing feature |
| **Design looks old (>3yrs)** | +15 | Needs refresh |
| **No SEO optimization** | +10 | Can't be found |
| **No about page** | +5 | No trust signal |
| **Low ratings (<3★)** | +10 | Needs rep boost |
| **New business (<1yr)** | +10 | Growing need |
| **Many reviews (50+)** | +10 | Active, needs site |
| **No Google Business Profile** | +10 | Missing presence |
| **Competitor nearby (5+)** | +10 | Losing leads |
| **No email in results** | +5 | Hard to reach |

#### SUBTRACT POINTS

| Factor | Points | Reason |
|--------|--------|--------|
| **Modern website** | -25 | Already has |
| **E-commerce enabled** | -20 | Already selling |
| **Online booking** | -15 | Tech-savvy |
| **Blog/News section** | -10 | Active marketing |
| **High ratings (4.5★+)** | -10 | Doing well |
| **Many photos** | -5 | Invested in presence |
| **Video content** | -5 | Modern approach |

---

## Priority Levels

| Score | Priority | Color | Action |
|-------|----------|-------|--------|
| 80-100 | 🔥 **HOT** | Red | Call within 24h |
| 65-79 | 🟡 **WARM** | Yellow | Email within 3 days |
| 50-64 | 🟢 **COOL** | Green | Add to nurture list |
| 35-49 | 🔵 **COLD** | Blue | Long-term follow-up |
| 0-34 | ⚪ **SKIP** | Gray | Don't pursue |

---

## Categories - High Priority

| Category | Keywords | Urgency |
|----------|----------|---------|
| Barbershops | barbershop, barber | HIGH |
| Hair Salons | hair salon, salon | HIGH |
| Plumbers | plumber, plumbing | HIGH |
| Electricians | electrician, electrical | HIGH |
| HVAC | hvac, heating, cooling | HIGH |
| Auto Repair | auto repair, mechanic | HIGH |
| Landscapers | landscaper, lawn care | HIGH |
| Cleaning Services | cleaning, house cleaning | HIGH |
| Restaurants | restaurant, cafe | MEDIUM |
| Pet Grooming | pet grooming, dog grooming | HIGH |

---

## Categories - Medium Priority

| Category | Keywords | Urgency |
|----------|----------|---------|
| Dentists | dentist, dental | MEDIUM |
| Lawyers | lawyer, attorney | MEDIUM |
| Real Estate | real estate, realtor | MEDIUM |
| Gyms | gym, fitness | MEDIUM |
| Chiropractors | chiropractor | MEDIUM |
| Veterinarians | vet, veterinarian | MEDIUM |
| Photographers | photographer | MEDIUM |
| Caterers | catering, caterer | MEDIUM |
| Event Planners | event planner | MEDIUM |
| Movers | moving company | MEDIUM |

---

## Categories - Low Priority (Long Game)

| Category | Keywords | Urgency |
|----------|----------|---------|
| Accountants | accountant, cpa | LOW |
| Insurance | insurance agent | LOW |
| Financial Advisors | financial advisor | LOW |
| Doctors | doctor, physician | LOW |
| Therapists | therapist | LOW |
| Consultants | consultant | LOW |

---

## Website Scoring Details

### Check Each Website For:

```
1. MOBILE
   - Has mobile version?
   - Responsive design?
   - Mobile-friendly test score

2. SPEED
   - Load time < 3s = good
   - Load time 3-5s = okay
   - Load time > 5s = bad

3. DESIGN
   - Year created (if detectable)
   - Stock photos used?
   - Modern layout?
   - Brand consistency?

4. FEATURES
   - Contact form?
   - Online booking?
   - E-commerce?
   - Blog?
   - Testimonials?
   - Social links?

5. SEO
   - Meta title/description?
   - Heading structure?
   - Image alt text?
   - Local SEO?

6. CONTENT
   - About page?
   - Services listed?
   - Pricing?
   - FAQ?
   - Location/hours?
```

---

## CRM Lead Schema

```json
{
  "lead_id": "lead_uuid",
  "business_name": "Joe's Barbershop",
  "owner_name": "Joe Smith",
  "phone": "+1-555-123-4567",
  "email": "joe@barbershop.com",
  "address": "123 Main St, City, ST 12345",
  "google_maps_url": "https://maps.google.com/...",
  "category": "barbershop",
  "rating": 4.2,
  "review_count": 47,
  
  "website_found": true,
  "website_url": "https://joesbarbershop.com",
  
  "scores": {
    "website_exists": -25,
    "mobile_friendly": 0,
    "load_speed": 0,
    "design_modern": -10,
    "contact_form": -10,
    "online_booking": 10,
    "seo_optimized": 0,
    "content_quality": -5,
    "business_signal": 15,
    "competition": 5
  },
  
  "total_score": 60,
  "priority": "warm",
  
  "source": "google_maps",
  "scraped_at": "2026-02-28T10:00:00Z",
  "assigned_to": null,
  "status": "new",
  "notes": "Has basic site, needs modern redesign"
}
```

---

## Outreach Templates

### HOT Lead - Call Script
```
"Hi, this is [name] from [company]. I noticed [business name] has great reviews online! 

I specialize in helping [category] businesses get more customers through a modern website. 

Do you have 5 minutes to chat about how you could be getting more bookings online?"
```

### WARM Lead - Email
```
Subject: Help [Business Name] Get More Customers

Hi [Name],

I noticed [Business Name] is doing great work in the community!

I help local businesses like yours get more leads through a professional website.

Would you be open to a quick 10-minute call to discuss some ideas?

Best,
[Name]
```

### COOL Lead - Nurture
```
Added to monthly newsletter:

"Top 5 Ways [Category] Businesses Can Get More Customers Online"
```

---

## Browser Safety Rules

1. ✅ Docker + Playwright only
2. ✅ Rate limit: 1 request per 2 seconds
3. ✅ Rotate user agents
4. ✅ Random scroll behavior
5. ✅ No aggressive scraping
6. ✅ Respect robots.txt where possible
7. ✅ Auto-cleanup after run
8. ✅ No data persistence on host

---

## Output

- **Hot leads**: Call within 24h
- **Warm leads**: Email within 3 days
- **Cool leads**: Add to newsletter
- **Skip**: Don't contact

---

*Lead Gen • Google Maps • CRM • Full Scoring*
## Quick Commands
- `skill-load lead-gen-expert` — Load this skill
