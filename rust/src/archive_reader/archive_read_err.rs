use gdnative::prelude::*;
use gdnative::core_types::{ToVariant, FromVariant, FromVariantError};

pub (crate) enum ZipReadErr {
    OK    = 0,
    ERROR = 1,
}

impl ToVariant for ZipReadErr
{
    fn to_variant(&self) -> Variant
    {
        match self
        {
            ZipReadErr::OK => { 0.to_variant() },
            ZipReadErr::ERROR => { 1.to_variant() },
        }
    }
}

impl FromVariant for ZipReadErr
{
    fn from_variant(variant: &Variant) -> Result<Self, FromVariantError>
    {
        let result = i64::from_variant(variant)?;
        match result
        {
            0 => Ok(ZipReadErr::OK),
            1 => Ok(ZipReadErr::ERROR),
            _ => Err(FromVariantError::UnknownEnumVariant {
                variant: "i64".to_owned(),
                expected: &["0", "1"],
            }),
        }
    }
}