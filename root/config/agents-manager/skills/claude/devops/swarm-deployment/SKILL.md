---
name: swarm-deployment
description: swarm-deployment skill
  Develops Docker Swarm deployment features including auto-scaling, load balancing,
  and domain routing. Activates when working with swarm services, Traefik middlewares,
  or swarm-specific application settings.
---

# Swarm Deployment

## When to Apply

Activate this skill when:
- Working with Docker Swarm deployments
- Adding auto-scaling functionality
- Configuring swarm load balancer domain mappings
- Setting up Traefik middlewares (rate limiting, headers, IP whitelist)

## Key Files (Coolify)

| File | Purpose |
|------|---------|
| `app/Jobs/AutoScaleSwarmJob.php` | Auto-scaling job for swarm services |
| `app/Models/SwarmDomainMapping.php` | Domain routing with Traefik labels |
| `app/Livewire/Settings/SwarmDomains.php` | UI for domain mapping management |
| `app/Livewire/Project/Application/Swarm.php` | Swarm configuration UI |
| `app/Models/Application.php` | Has swarm_service_identifier field |

## Application Model Fields

```php
'swarm_service_identifier' => 'string',  // Unique ID for load balancer routing
'auto_scaling_enabled' => 'boolean',
'auto_scaling_min_replicas' => 'integer',
'auto_scaling_max_replicas' => 'integer',
'auto_scaling_target_cpu' => 'integer',
'auto_scaling_target_memory' => 'integer',
```

## SwarmDomainMapping Fields

- **Basic**: domain, path_prefix, application_id, port, scheme, is_enabled
- **Rate Limiting**: rate_limit_average, rate_limit_burst, rate_limit_period
- **Security Headers**: enable_security_headers, header_xss_filter, header_content_type_nosniff, header_frame_deny, header_sts_seconds, header_sts_include_subdomains
- **IP Whitelist**: ip_whitelist_enabled, ip_whitelist_sources

## Traefik Labels Generation

The `SwarmDomainMapping::getTraefikLabels()` method generates:
- Router rules (Host + PathPrefix)
- Service ports
- Rate limiting middleware
- Custom headers middleware
- IP allowlist middleware

## Testing

- Test auto-scaling job with mock metrics
- Verify Traefik label generation
- Test domain mapping CRUD operations
- Verify middleware configurations

## Gotchas

- Traefik middleware must be defined BEFORE the router that uses it
- IP whitelist format: comma-separated CIDR notation (e.g., "10.0.0.0/8,192.168.1.0/24")
- rate_limit_period options: second, minute, hour, day
## Quick Commands
- `skill-load swarm-deployment` — Load this skill
