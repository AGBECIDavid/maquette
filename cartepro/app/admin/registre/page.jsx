import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "Registre des transactions" };

export default function Page() {
  return <Shell><AdminSpace section="registre" /></Shell>;
}
