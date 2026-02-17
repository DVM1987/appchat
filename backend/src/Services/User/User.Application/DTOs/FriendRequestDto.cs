namespace User.Application.DTOs
{
    public record FriendDto(
        Guid Id,
        Guid IdentityId,
        string FullName,
        string Email,
        string? AvatarUrl
    );

    public record FriendRequestDto(
        int FriendshipId,
        FriendDto Requester,
        DateTime CreatedAt,
        string Status
    );
}
