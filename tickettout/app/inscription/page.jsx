"use client";
import { Shell } from "../../components/Shell.jsx";
import { Signup } from "../../screens/Auth.jsx";
import { useNav } from "../../lib/app.jsx";

export default function Page() {
  const { path } = useNav();
  const role = String(path || "").includes("role=partner") ? "partner" : "employee";
  return <Shell><Signup initialRole={role} /></Shell>;
}
