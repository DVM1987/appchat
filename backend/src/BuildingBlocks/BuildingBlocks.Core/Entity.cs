using System.Collections.Generic;

namespace BuildingBlocks.Core
{
    public abstract class Entity<TId>
    {
        public TId Id { get; protected set; }
        
        // Basic equality logic can be added here if needed
        // Usually checked by Id
        
        public override bool Equals(object obj)
        {
            if (obj is not Entity<TId> other)
                return false;

            if (ReferenceEquals(this, other))
                return true;
            
            if (EqualityComparer<TId>.Default.Equals(Id, default) || 
                EqualityComparer<TId>.Default.Equals(other.Id, default))
                return false;

            return EqualityComparer<TId>.Default.Equals(Id, other.Id);
        }

        public override int GetHashCode()
        {
            return EqualityComparer<TId>.Default.GetHashCode(Id);
        }

        public static bool operator ==(Entity<TId> a, Entity<TId> b)
        {
            if (ReferenceEquals(a, null) && ReferenceEquals(b, null))
                return true;
            if (ReferenceEquals(a, null) || ReferenceEquals(b, null))
                return false;
            return a.Equals(b);
        }

        public static bool operator !=(Entity<TId> a, Entity<TId> b)
        {
            return !(a == b);
        }
    }
}
