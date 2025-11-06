# from fastapi import APIRouter, HTTPException
# from pydantic import BaseModel
# import httpx
# from bs4 import BeautifulSoup

# router = APIRouter(tags=["Results"])


# class ResultRequest(BaseModel):
#     register_number: str
#     dob: str  # Format: DD/MM/YYYY or the format expected by TEC site


# @router.post("/getResult")
# async def get_result(data: ResultRequest):
#     try:
#         url = "https://results.tec-edu.in/"   # TEC result site

#         # ✅ 1. Create session
#         async with httpx.AsyncClient(follow_redirects=True) as client:

#             # ✅ 2. First GET request to load page
#             first = await client.get(url)

#             # ✅ 3. Prepare form data
#             form_data = {
#                 "reg_no": data.register_number,
#                 "dob": data.dob,
#                 "submit": "Submit"
#             }

#             # ✅ 4. Submit the result request
#             res = await client.post(url, data=form_data)

#         # ✅ 5. Parse HTML response
#         soup = BeautifulSoup(res.text, "html.parser")

#         # Example: TEC usually returns a <table> of results
#         table = soup.find("table")
#         if not table:
#             raise HTTPException(status_code=404, detail="Result not found or server changed the structure")

#         rows = table.find_all("tr")

#         results = []
#         for row in rows[1:]:  # Skip header
#             cols = [td.get_text(strip=True) for td in row.find_all("td")]
#             if len(cols) >= 3:
#                 results.append({
#                     "subject_code": cols[0],
#                     "subject_name": cols[1],
#                     "grade": cols[2]
#                 })

#         # ✅ Extract SGPA if available
#         sgpa = soup.find("span", {"id": "sgpa"})
#         sgpa_value = sgpa.text.strip() if sgpa else "Not Available"

#         return {
#             "status": "success",
#             "register_number": data.register_number,
#             "sgpa": sgpa_value,
#             "results": results
#         }

#     except Exception as e:
#         print(f"Error fetching result: {str(e)}")
#         raise HTTPException(status_code=500, detail=f"Error fetching result: {str(e)}")
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx
from bs4 import BeautifulSoup

router = APIRouter(tags=["Results"])

class ResultRequest(BaseModel):
    register_number: str
    dob: str  # DD-MM-YYYY

@router.post("/getResult")
async def get_result(data: ResultRequest):
    url = "https://results.tec-edu.in/"

    headers = {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://results.tec-edu.in/",
        "Origin": "https://results.tec-edu.in",
    }

    form_data = {
        "reg_no": data.register_number,
        "dob": data.dob
    }

    try:
        async with httpx.AsyncClient(headers=headers, follow_redirects=True) as client:
            await client.get(url)  
            res = await client.post(url, data=form_data)

        soup = BeautifulSoup(res.text, "html.parser")

        # ✅ Find the FIRST table → student info
        info_table = soup.find("table", class_="table-bordered")
        if not info_table:
            raise HTTPException(status_code=404, detail="Result not found")

        student_data = {}

        # ✅ Extract all <th> and their next <td>
        for th in info_table.find_all("th"):
            key = th.get_text(strip=True)
            td = th.find_next_sibling("td")
            if td:
                student_data[key] = td.get_text(strip=True)

        # ✅ Now extract subjects from second table
        subject_table = soup.find("table", class_="table-bg")
        if not subject_table:
            raise HTTPException(status_code=404, detail="Subjects not found")

        subjects = []
        rows = subject_table.find_all("tr")[1:]  # skip header

        for row in rows:
            cols = [c.get_text(strip=True) for c in row.find_all("td")]
            if len(cols) >= 7:
                subjects.append({
                    "semester": cols[0],
                    "course_name": cols[1],
                    "code": cols[2],
                    "credits": cols[3],
                    "grade": cols[4],
                    "grade_point": cols[5],
                    "result": cols[6],
                })

        # ✅ Compute SGPA safely
        try:
            total_credits = sum(float(s["credits"]) for s in subjects)
            weighted = sum(float(s["credits"]) * float(s["grade_point"]) for s in subjects)
            sgpa = round(weighted / total_credits, 2)
        except:
            sgpa = "Not Available"

        # ✅ Build final response
        return {
            "status": "success",
            "register_number": student_data.get("Registration Number", ""),
            "name": student_data.get("Name", ""),
            "degree": student_data.get("Degree", ""),
            "exam_month": student_data.get("Month & Year of Examinations", ""),
            "sgpa": sgpa,
            "subjects": subjects
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
