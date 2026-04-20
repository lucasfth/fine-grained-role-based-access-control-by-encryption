
== Key Management and RBAC

To ensure security for how keys are managed, we will support keys stored within, e.g. Azure Key Vault.
The important thing is that we will ensure that various systems should be supported as long as our (code-specific) interface is implemented.

The flow for decryption (as Azure Key vault does not allow for exporting keys out) will be to:

+ OSWS will check if the identity has access to the given key, we can read from the parquet in Azure or other
+ Given that they have, OSWS will forward the byte sequence (e.g. of the footer) to Azure with the key id
+ OSWS will then get the decrypted byte sequence back, which it will have to use to rebuild the parquet.
+ Parquet file, which might be partially decrypted, will be returned to the client.

This means that the OSWS has to have some internal DB to handle the mapping of keys coupled to columns, and which columns are mapped to roles.
If this is not done, OSWS cannot provide a functionality to map roles to columns as Azure has no idea of which columns exists.
Thus, OSWS has to actually say when someone wants to grant a group permissions to columns, it will call Azure with all of the keys that needs to be mapped to a group.

Furthermore, OSWS cannot redirect S3 calls.
Thus, it needs some IAM policy itself allowing it to make all CRUD actions in the actual S3.
This means that IAM policies have to be handled in the OSWS, which can be coupled to the Key Vault set up in the Azure Key Vault or other.