use gdnative::prelude::*;
use gdnative::core_types::{ToVariant, FromVariant, FromVariantError};

pub (crate) enum ZipWriteErr {
    OK    = 0,
    ERROR = 1,
}

impl ToVariant for ZipWriteErr
{
    fn to_variant(&self) -> Variant
    {
        match self
        {
            ZipWriteErr::OK => { 0.to_variant() },
            ZipWriteErr::ERROR => { 1.to_variant() },
        }
    }
}

impl FromVariant for ZipWriteErr
{
    fn from_variant(variant: &Variant) -> Result<Self, FromVariantError>
    {
        let result = i64::from_variant(variant)?;
        match result
        {
            0 => Ok(ZipWriteErr::OK),
            1 => Ok(ZipWriteErr::ERROR),
            _ => Err(FromVariantError::UnknownEnumVariant {
                variant: "i64".to_owned(),
                expected: &["0", "1"],
            }),
        }
    }
}