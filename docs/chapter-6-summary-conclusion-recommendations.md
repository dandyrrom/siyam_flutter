# CHAPTER 6

# SUMMARY, CONCLUSION, AND RECOMMENDATIONS

## 6.1 Summary

This capstone project developed SIYAM, a cross-platform shelter inventory and audit management system for Dumaguete Animal Sanctuary (DAS). The system supports three registered roles - Manager, Staff, and Donor - and covers the sanctuary's core operations: inventory and stock movement, purchase and replenishment ordering, animal records, medical treatments linked to supply use, donation intake and history, alerts and notifications, reporting, audit trail, and a donor-facing portal with impact information.

SIYAM was built with Flutter and Dart as a single codebase. It runs primarily as a Flutter Web application and also targets Android. Backend services use Supabase for authentication and cloud database storage, with the production web build deployed on Vercel. The implemented modules replace manual logbook tracking with role-based digital workflows suited to daily sanctuary work and donor engagement.

## 6.2 Conclusion

The project has met its stated objectives. SIYAM automates stock tracking, supports donation tracking and history, links treatment activities to inventory updates and animal medical information, applies threshold-based inventory monitoring, provides reporting on usage and resource consumption, and presents accessible, up-to-date information on inventory, animals, and treatments for authorized users and, where applicable, public impact content.

Overall, the system demonstrates that a unified Flutter application with a Supabase backend can deliver reliable, role-appropriate tools for a nonprofit animal sanctuary. SIYAM addresses the operational gaps of paper-based inventory and audit practices at DAS and provides a maintainable foundation for continued shelter management and donor transparency.

## 6.3 Recommendations

The application is ready for deployment. It is recommended that Dumaguete Animal Sanctuary adopt and use SIYAM in its day-to-day operations so that staff, managers, and donors can benefit from accurate inventory records, traceable medical and donation workflows, and timely operational reporting.
