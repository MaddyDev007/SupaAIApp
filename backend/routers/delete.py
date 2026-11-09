from fastapi import APIRouter, HTTPException, Depends

from security import authenticated_user, ensure_teacher_owns_class, supabase_admin
from services.private_storage import storage_path_from_reference

router = APIRouter()
supabase = supabase_admin

# 🔁 Helper: convert public URL → storage path
def extract_storage_path(url: str, bucket: str) -> str:
    return storage_path_from_reference(url, bucket)


@router.delete("/class")
def delete_class(
    class_id: str,
    user: dict = Depends(authenticated_user),
):
    try:
        ensure_teacher_owns_class(user["id"], class_id)
        # 1️⃣ MATERIALS → lessons bucket
        materials = (
            supabase.table("materials")
            .select("file_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )

        if materials:
            paths = [
                extract_storage_path(m["file_url"], "lessons")
                for m in materials
                if m.get("file_url")
            ]
            if paths:
                supabase.storage.from_("lessons").remove(paths)

        # 2️⃣ QUESTIONS → questions bucket (flat)
        quizzes = (
            supabase.table("questions")
            .select("file_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )

        if quizzes:
            paths = [
                extract_storage_path(q["file_url"], "questions")
                for q in quizzes
                if q.get("file_url")
            ]
            if paths:
                supabase.storage.from_("questions").remove(paths)

        # 3️⃣ NOTES → notes bucket (flat). The class-delete confirmation
        # explicitly warns that class notes are removed with the class.
        notes = (
            supabase.table("notes")
            .select("image_url")
            .eq("class_id", class_id)
            .execute()
            .data
        )
        if notes:
            paths = [
                extract_storage_path(note["image_url"], "notes")
                for note in notes
                if note.get("image_url")
            ]
            if paths:
                supabase.storage.from_("notes").remove(paths)

        # 4️⃣ Delete class (DB cascade removes rows)
        supabase.table("classes") \
            .delete() \
            .eq("id", class_id) \
            .execute()

        return {
            "status": "success",
            "message": "Class, database rows, and storage files deleted"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/student")
def delete_student_from_class(
    class_id: str,
    student_id: str,
    user: dict = Depends(authenticated_user),
):
    """Remove a student and the related class-scoped records.

    This privileged operation is explicitly confirmed in the teacher UI. It
    deletes note images by path without returning note contents to the teacher.
    """
    try:
        ensure_teacher_owns_class(user["id"], class_id)
        if student_id == user["id"]:
            raise HTTPException(status_code=400, detail="Cannot remove yourself as a student")

        membership = (
            supabase.table("class_members")
            .select("id")
            .eq("class_id", class_id)
            .eq("user_id", student_id)
            .eq("student", True)
            .maybe_single()
            .execute()
            .data
        )
        if not membership:
            raise HTTPException(status_code=404, detail="Student membership not found")

        notes = (
            supabase.table("notes")
            .select("image_url")
            .eq("class_id", class_id)
            .eq("user_id", student_id)
            .execute()
            .data
        ) or []
        paths = [
            extract_storage_path(note["image_url"], "notes")
            for note in notes
            if note.get("image_url")
        ]
        if paths:
            supabase.storage.from_("notes").remove(paths)

        supabase.table("notes").delete().eq("class_id", class_id).eq(
            "user_id", student_id
        ).execute()
        supabase.table("results").delete().eq("class_id", class_id).eq(
            "student_id", student_id
        ).execute()
        supabase.table("class_members").delete().eq("class_id", class_id).eq(
            "user_id", student_id
        ).eq("student", True).execute()

        return {"status": "success", "message": "Student removed from class"}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to remove student from class")

