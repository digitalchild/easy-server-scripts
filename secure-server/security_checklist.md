# VPS Security Checklist

## Initial Server Setup

- [ ] Change default SSH port from 22
- [ ] Disable root SSH login
- [ ] Configure SSH key-based authentication
- [ ] Remove password authentication
- [ ] Create non-root admin user with sudo privileges
- [ ] Set secure passwords for all accounts
- [ ] Update system packages
- [ ] Set correct file permissions on key directories

## Firewall Configuration

- [ ] Install and enable UFW
- [ ] Configure essential ports only
- [ ] Set default deny policies
- [ ] Enable rate limiting for services
- [ ] Configure connection tracking
- [ ] Document all open ports and their purpose
- [ ] Test firewall configuration
- [ ] Set up logging for denied connections

## Intrusion Prevention

- [ ] Install and configure Fail2ban
- [ ] Set up custom jail rules
- [ ] Configure monitoring alerts
- [ ] Enable log monitoring
- [ ] Set appropriate ban times
- [ ] Configure email notifications
- [ ] Test intrusion detection
- [ ] Document unban procedures

## Malware Protection

- [ ] Install ClamAV
- [ ] Configure Rootkit Hunter
- [ ] Schedule automated scans
- [ ] Set up email notifications
- [ ] Configure quarantine location
- [ ] Set up scan logs
- [ ] Test malware detection
- [ ] Document incident response procedures

## Automatic Updates

- [ ] Configure unattended-upgrades
- [ ] Set up package cleanup
- [ ] Enable update notifications
- [ ] Configure update schedule
- [ ] Set up update logging
- [ ] Test update process
- [ ] Document rollback procedures
- [ ] Configure selective updates for critical packages

## Monitoring and Maintenance

- [ ] Set up resource monitoring
- [ ] Configure log monitoring
- [ ] Enable uptime monitoring
- [ ] Implement backup system
- [ ] Set up performance monitoring
- [ ] Configure disk space alerts
- [ ] Enable network monitoring
- [ ] Set up service monitoring

## Documentation

- [ ] Document all security configurations
- [ ] Create incident response plan
- [ ] Record all open ports and services
- [ ] Document backup procedures
- [ ] Keep software inventory
- [ ] Maintain update history
- [ ] Document emergency contacts
- [ ] Keep configuration change log

## Regular Maintenance Tasks

- [ ] Review security logs
- [ ] Test backup restoration
- [ ] Update security policies
- [ ] Verify monitoring systems
- [ ] Check system performance
- [ ] Review user accounts
- [ ] Test disaster recovery
- [ ] Update documentation

Feel free to fork this checklist and customize it for your specific needs. Remember to regularly review and update your security measures as new threats emerge and best practices evolve.
