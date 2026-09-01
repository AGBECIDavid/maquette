import { Shell } from "../../../components/Shell.jsx";
import { EmployeeSpace } from "../../../screens/Employee.jsx";

export const metadata = { title: "Partenaires" };

export default function Page() {
  return <Shell><EmployeeSpace section="partenaires" /></Shell>;
}
