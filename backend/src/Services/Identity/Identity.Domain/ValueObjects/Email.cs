using BuildingBlocks.Core;
using System.Collections.Generic;

namespace Identity.Domain.ValueObjects
{
    public class Email : ValueObject
    {
        public string Value { get; private set; }

        public Email(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new System.ArgumentException("Email cannot be empty", nameof(value));
            // Add regex validation if needed
            Value = value.ToLowerInvariant();
        }

        protected override IEnumerable<object> GetEqualityComponents()
        {
            yield return Value;
        }
    }
}
