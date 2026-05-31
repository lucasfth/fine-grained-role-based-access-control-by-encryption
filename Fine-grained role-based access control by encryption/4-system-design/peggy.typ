#figure(
  kind: "listing",
  supplement: "Listing",
  caption: [Example statements and their parsed API calls],
  (```sql
CREATE ROLE admin;
=> POST /api/admin/roles { name: "admin" }
CREATE ROLE intern;
=> POST /api/admin/roles { name: "intern" }
GRANT intern TO ROLE admin;
=> POST /api/admin/roles/1/inherit/2
GRANT ACCESS ON name TO intern;
=> POST /api/admin/columns/1/roles/1
GRANT ACCESS ON ssn TO admin;
=> POST /api/admin/columns/2/roles/2
GRANT admin TO USER alice;
=> POST /api/admin/users/1/roles/1
```)
)<listing:peggy>
