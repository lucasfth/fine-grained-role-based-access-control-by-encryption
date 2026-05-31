# Fine-grained Role-Based Access Control in Data Lakes by Encryption

Computer Science Thesis. Made by @duckth and @lucasfth

## Abstract

True separation of compute and data in data lakes comes at the cost of coarse access control.
Authorization services, like Lakekeeper, introduce access control for any query engine, but limit authorization to the file level. 
On the other hand, "fully managed all-in-one cloud platforms" like Snowflake offer fine-grained access control only within their own platform -- defeating the purpose of separating compute and data.

We propose Object Store Wrapper Service (OSWS), a system that enforces column-level role-based access control at the Object Store layer using Parquet Modular Encryption with envelope encryption, and still supports query engines that are already S3-compatible, with no modifications.

Our evaluation, based on end-to-end latency benchmarks, shows that OSWS adds low absolute overhead for reading small Parquet files.
With a warm DEK cache, a _0.5_ MB Parquet file reaches a _p95_ latency of _37_ milliseconds, remaining practically fast, though still adding a _\~2.5_#sym.times overhead compared to direct S3 access.
However, for larger files, the current implementation becomes impractically slow.
We reflect on how these issues could be addressed through different fundamental design changes in OSWS.

OSWS demonstrates that encryption-based fine-grained access control at the Object Store layer is a feasible approach for data lakes, though query engines that cache Parquet metadata pose limitations; however, those issues are addressable.

```bibtex
@misc{2026-trøstrup-hanson-fine-grained-role-based-access-control-in-data-lakes-by-encryption,
  title={Fine-grained Role-Based Access Control in Data Lakes by Encryption},
  author={Andreas Severin Hauch Trøstrup and Lucas Frey Torres Hanson},
  year={2026},
  url={https://github.com/lucasfth/fine-grained-role-based-access-control-by-encryption},
  abstractNote={True separation of compute and data in data lakes comes at the cost of coarse access control. Authorization services, like Lakekeeper, introduce access control for any query engine, but limit authorization to the file level. On the other hand, "fully managed all-in-one cloud platforms" like Snowflake offer fine-grained access control only within their own platform -- defeating the purpose of separating compute and data.
  We propose Object Store Wrapper Service (OSWS), a system that enforces column-level role-based access control at the Object Store layer using Parquet Modular Encryption with envelope encryption, and still supports query engines that are already S3-compatible, with no modifications.
  Our evaluation, based on end-to-end latency benchmarks, shows that OSWS adds low absolute overhead for reading small Parquet files. With a warm DEK cache, a _0.5_ MB Parquet file reaches a _p95_ latency of _37_ milliseconds, remaining practically fast, though still adding a _\~2.5_#sym.times overhead compared to direct S3 access. However, for larger files, the current implementation becomes impractically slow. We reflect on how these issues could be addressed through different fundamental design changes in OSWS.
  OSWS demonstrates that encryption-based fine-grained access control at the Object Store layer is a feasible approach for data lakes, though query engines that cache Parquet metadata pose limitations; however, those issues are addressable.
},
  journal={GitHub},
  language={en}
}
```
