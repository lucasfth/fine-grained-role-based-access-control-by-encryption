#figure(
  placement: top,
  scope: "parent",
  kind: "figure",
  supplement: "Figure",
  caption: [Entity Relationship Diagram showing the design of the database],
  (```pintora
  erDiagram
    User {
        int Id PK
        string Name
        string Email
        bool IsRbacAdmin
    }

    Role {
        int Id PK
        string Name
    }


    RoleInheritance {
        int ParentRoleId FK
        int ChildRoleId FK
    }

    ExternalIdentity {
        int Id PK
        string Provider
        string Subject
        string Email
        int UserId FK
        datetime CreatedAt
        datetime LastSeenAt
    }
    
    RoleAssignment {
        int UserId FK
        int RoleId FK
    }

    S3Credential {
        int Id PK
        string AccessKeyId
        string SecretKey
        int UserId FK
        int DefaultRoleId FK
        datetime CreatedAt
        bool IsActive
    }

    Column {
        int Id PK
        string Name
    }

    Permission {
        int Id PK
        int RoleId FK
        int ColumnId FK
    }

    Key {
        int Id PK
        string Name
        string KeyVaultId
        int ColumnId FK
    }

    User ||--o{ RoleAssignment : "has"
    Role ||--o{ RoleAssignment : "assigned to"

    Role ||--o{ RoleInheritance : "is parent/child in"

    User ||--o{ ExternalIdentity : "identified by"

    User ||--o{ S3Credential : "owns"
    Role ||--o{ S3Credential : "default role for"

    Role ||--o{ Permission : "granted"
    Column ||--o{ Permission : "secured by"

    Column ||--o{ Key : "encrypted with"
```)
)<fig:er-diagram>
