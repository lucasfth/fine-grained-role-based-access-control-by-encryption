#figure(
  kind: "listing",
  supplement: "Listing",
  caption: [A recursive SQL query to get the full set of effective roles given a `userId`.],
  (
    ```sql
  WITH RECURSIVE effective AS (
    SELECT ra."RoleId" AS "Id"
    FROM "RoleAssignments" ra
    WHERE ra."UserId" = {userId}
    UNION
    SELECT ri."ChildRoleId"
    FROM "RoleInheritances" ri
    JOIN effective e
    ON ri."ParentRoleId" = e."Id"
  )
  SELECT DISTINCT r."Id", r."Name"
  FROM "Roles" r
  JOIN effective e ON r."Id" = e."Id"
```
  )
)<listing:effective-roles>
