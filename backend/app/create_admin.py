import argparse
import getpass

from pydantic import EmailStr, TypeAdapter
from sqlalchemy import select

from .database import SessionLocal
from .models import User
from .security import hash_password


def main() -> None:
    parser = argparse.ArgumentParser(description="Create or promote a LifeTrace administrator")
    parser.add_argument("--email", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--phone", required=True)
    args = parser.parse_args()
    email = str(TypeAdapter(EmailStr).validate_python(args.email)).lower()
    password = getpass.getpass("Admin password (not displayed): ")
    if len(password) < 6:
        raise SystemExit("Admin password must be at least 6 characters.")

    with SessionLocal() as db:
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            user = User(
                full_name=args.name,
                email=email,
                password_hash=hash_password(password),
                phone_number=args.phone,
                emergency_contact_name="Administrator",
                emergency_contact_phone=args.phone,
                blood_group="N/A",
                role="admin",
            )
            db.add(user)
        else:
            user.role = "admin"
            user.password_hash = hash_password(password)
        db.commit()
    print(f"Administrator ready: {email}")


if __name__ == "__main__":
    main()
