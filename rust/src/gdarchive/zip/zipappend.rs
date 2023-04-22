use gdnative::prelude::*;


#[derive(ToVariant)]
pub enum ZipAppend
{
    AppendCreate = 0,
    /// [Zip will be created at the end of the file (useful if the file contains self extractor code).](https://github.com/mattconnolly/ZipArchive/blob/e215573f43d7c008b9baaa0d8709363aa6445dbd/minizip/zip.h#L119)
    #[allow(dead_code)]
    AppendCreateAfter = 1,
    /// [Add files in existing zip (be sure you don't add a file that doesn't exist).](https://github.com/mattconnolly/ZipArchive/blob/e215573f43d7c008b9baaa0d8709363aa6445dbd/minizip/zip.h#L119)
    #[allow(dead_code)]
    AppendAddInZip = 2,
}

impl Into<i32> for ZipAppend
{
    fn into(self) -> i32
    {
        match self
        {
            ZipAppend::AppendCreate => 0,
            ZipAppend::AppendCreateAfter => 1,
            ZipAppend::AppendAddInZip => 2,
        }
    }
}

impl FromVariant for ZipAppend
{
    fn from_variant(variant: &Variant) -> Result<Self, FromVariantError>
    {
        let result = i64::from_variant(variant)?;
        match result
        {
            0 => Ok(ZipAppend::AppendCreate),
            1 => Ok(ZipAppend::AppendCreateAfter),
            2 => Ok(ZipAppend::AppendAddInZip),
            _ => Err(FromVariantError::UnknownEnumVariant {
                variant: "i64".to_owned(),
                expected: &["0", "1"],
            }),
        }
    }
}

impl Default for ZipAppend
{
    fn default() -> Self { ZipAppend::AppendCreate }
}